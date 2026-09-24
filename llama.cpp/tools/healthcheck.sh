#!/usr/bin/env bash
#
# healthcheck.sh — detect a llama-server whose model has been evicted from VRAM
# into host memory at runtime, and restart the unit that owns it.
#
# Why this exists (measured on Gertrude, 2026-09-24): a single llama-server sat
# at 20405 MiB VRAM / 1610 MiB GTT right after loading and at 26 MiB VRAM /
# 15986 MiB GTT a few minutes later — same process, no restart in between.
# amdgpu had evicted the model into host RAM. llama-server neither notices nor
# reports it: it keeps answering, far slower, while pinning ~16 GiB of system
# RAM as GTT. One such episode ran undetected for two days and left the box with
# 273 MiB free RAM and a full swap.
#
# The check therefore has to be periodic. A one-shot probe after loading would
# have passed every single time — that is exactly why the fault went unnoticed.
#
# PORTABILITY: the VRAM/GTT signal is amdgpu-specific and does NOT transfer to
# the CUDA host (hermine). There the Windows driver spills into shared memory
# while nvidia-smi's "used" still looks plausible (measured, see AGENTS.md), so
# the same threshold would never fire. That machine needs a throughput probe
# instead. Detection is isolated in detect_* below for that reason; add
# detect_throughput and select it with LLAMA_HEALTHCHECK_DETECTOR.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLAMA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../config-load.sh
source "$LLAMA_DIR/config-load.sh"
_llama_load_config "$LLAMA_DIR"

# All knobs come from config.env (single source of truth, see config-load.sh).
LLAMA_HEALTHCHECK_UNIT="${LLAMA_HEALTHCHECK_UNIT:-llama-server.service}"
LLAMA_HEALTHCHECK_DETECTOR="${LLAMA_HEALTHCHECK_DETECTOR:-auto}"
LLAMA_HEALTHCHECK_MIN_GTT_MIB="${LLAMA_HEALTHCHECK_MIN_GTT_MIB:-4096}"
LLAMA_HEALTHCHECK_STRIKES="${LLAMA_HEALTHCHECK_STRIKES:-2}"
LLAMA_HEALTHCHECK_STATE="${LLAMA_HEALTHCHECK_STATE:-$HOME/.local/state/llama.cpp}"
LLAMA_HEALTHCHECK_LOG="${LLAMA_HEALTHCHECK_LOG:-$LLAMA_HEALTHCHECK_STATE/healthcheck.log}"
LLAMA_HEALTHCHECK_RESTART="${LLAMA_HEALTHCHECK_RESTART:-1}"

mkdir -p "$LLAMA_HEALTHCHECK_STATE"
STRIKE_FILE="$LLAMA_HEALTHCHECK_STATE/healthcheck.strikes"

log() { printf '%s %s\n' "$(date -Is)" "$*" >>"$LLAMA_HEALTHCHECK_LOG"; }

# --- detectors --------------------------------------------------------------
# A detector prints "<vram_mib> <gtt_mib>" or nothing if it cannot measure.

detect_amdgpu() {
    local d vram gtt
    for d in /sys/class/drm/card*/device; do
        [[ -r "$d/mem_info_vram_used" && -r "$d/mem_info_gtt_used" ]] || continue
        vram="$(cat "$d/mem_info_vram_used")"
        gtt="$(cat "$d/mem_info_gtt_used")"
        printf '%s %s\n' "$(( vram / 1048576 ))" "$(( gtt / 1048576 ))"
        return 0
    done
    return 1
}

# Test hook. The eviction branch cannot be reached on demand -- it needs
# gtt > vram, which only the real fault produces -- so without this the most
# important path would ship untested. Set LLAMA_HEALTHCHECK_DETECTOR="fake:26 15986"
# in config.env to replay the values measured during the 2026-09-24 incident.
detect_fake() {
    printf '%s\n' "${LLAMA_HEALTHCHECK_DETECTOR#fake:}"
}

pick_detector() {
    case "$LLAMA_HEALTHCHECK_DETECTOR" in
        fake:*) printf 'detect_fake\n' ;;
        amdgpu) printf 'detect_amdgpu\n' ;;
        auto)
            if detect_amdgpu >/dev/null 2>&1; then printf 'detect_amdgpu\n'; else printf '\n'; fi ;;
        *)  printf '\n' ;;
    esac
}

server_running() {
    pgrep -f '[l]lama-server' >/dev/null 2>&1
}

# Recovery must restore the known state, not change it. The serving unit starts
# via server.sh, which runs bootstrap.sh on every start; with LLAMA_VERSION=
# "latest" the check's own restart would install whatever build is newest and
# rm -rf the old one -- unattended, mid-incident. That matters because a build
# can change the VRAM footprint (b10964 -> b11146 cost +775 MiB against a
# 22461 MiB throttle cliff): a heavier build could stop fitting, evict again,
# and put the check in a restart loop. It also makes the log below incomparable
# across entries, which is the one thing it exists for.
#
# Auto-update itself stays fully enabled -- the hourly check, manual restarts
# and boots all update as before. Only this restart skips it, and the previous
# marker is put back afterwards so the regular schedule is not delayed at all.
# Note there is no env-var route for this: config.env is authoritative since
# 2026-09-24, so LLAMA_AUTO_UPDATE=0 in the environment has no effect.
restart_without_update() {
    local marker="$LLAMA_DIR/vendor/.last-auto-check" saved="" had=0
    if [[ -f "$marker" ]]; then saved="$(cat "$marker" 2>/dev/null || true)"; had=1; fi

    if [[ -d "$LLAMA_DIR/vendor" ]] && date +%s >"$marker" 2>/dev/null; then
        log "auto-update skipped for this restart (schedule unchanged)"
    else
        log "WARNING cannot write $marker — this restart may also install a new build"
    fi

    log "RESTART $LLAMA_HEALTHCHECK_UNIT"
    if systemctl --user restart "$LLAMA_HEALTHCHECK_UNIT"; then
        log "RESTART ok"
    else
        log "RESTART FAILED"
    fi

    # Put the throttle back where it was, so the next scheduled check lands at
    # its original time instead of an hour after this incident.
    if (( had )) && [[ -n "$saved" ]]; then
        printf '%s' "$saved" >"$marker" 2>/dev/null || true
    elif (( ! had )); then
        rm -f "$marker" 2>/dev/null || true
    fi
}

# --- main -------------------------------------------------------------------
main() {
    local detector; detector="$(pick_detector)"
    if [[ -z "$detector" ]]; then
        log "ERROR no usable detector (LLAMA_HEALTHCHECK_DETECTOR=$LLAMA_HEALTHCHECK_DETECTOR); this host needs a throughput probe, see header"
        exit 2
    fi

    # Nothing serving -> nothing to check, and no strike either: a stopped
    # server must not accumulate toward a restart.
    if ! server_running; then
        : >"$STRIKE_FILE"
        exit 0
    fi

    local out vram gtt
    out="$($detector)" || { log "ERROR detector $detector failed"; exit 2; }
    read -r vram gtt <<<"$out"

    # Evicted = the host holds more of the model than the card does, and it is
    # not a rounding-scale amount. Both conditions matter: an idle router sits
    # at ~26/15 MiB and must not trip the first one.
    if (( gtt > LLAMA_HEALTHCHECK_MIN_GTT_MIB && gtt > vram )); then
        local strikes=0
        [[ -s "$STRIKE_FILE" ]] && strikes="$(cat "$STRIKE_FILE")"
        strikes=$(( strikes + 1 ))
        printf '%s' "$strikes" >"$STRIKE_FILE"
        log "EVICTED vram=${vram}MiB gtt=${gtt}MiB strike=${strikes}/${LLAMA_HEALTHCHECK_STRIKES}"

        if (( strikes >= LLAMA_HEALTHCHECK_STRIKES )); then
            : >"$STRIKE_FILE"
            if (( LLAMA_HEALTHCHECK_RESTART )); then
                restart_without_update
            else
                log "RESTART suppressed (LLAMA_HEALTHCHECK_RESTART=0)"
            fi
        fi
        exit 0
    fi

    # Healthy: clear the counter so isolated blips never add up to a restart.
    [[ -s "$STRIKE_FILE" ]] && log "RECOVERED vram=${vram}MiB gtt=${gtt}MiB"
    : >"$STRIKE_FILE"
}

main "$@"
