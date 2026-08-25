#!/usr/bin/env bash
#
# bootstrap.sh — install FreeToken into a local venv and calibrate the MoE backend.
#
# FreeToken is a Python package (Linux-only wheels), not a prebuilt binary tarball
# like llama.cpp. This script creates ./.venv with uv, installs "freetoken[accel]",
# checks the CUDA 13 toolchain the JIT kernels need, and runs `ft bench bw` once to
# write the per-GPU bandwidth profile that `--moe-backend auto` reads.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=config-load.sh
source "$SCRIPT_DIR/config-load.sh"
_ft_load_config "$SCRIPT_DIR"

FT_VERSION="${FT_VERSION:-latest}"
VENV_DIR="$SCRIPT_DIR/.venv"
PY="$VENV_DIR/bin/python"
FT="$VENV_DIR/bin/ft"

# --- args ------------------------------------------------------------------
FORCE=0
SKIP_CUDA_CHECK=0
NO_BENCH=0
for arg in "$@"; do
    case "$arg" in
        -f|--force)        FORCE=1 ;;
        --skip-cuda-check) SKIP_CUDA_CHECK=1 ;;
        --no-bench)        NO_BENCH=1 ;;
        -h|--help)
            cat <<EOF
Usage: bootstrap.sh [--force] [--skip-cuda-check] [--no-bench]

Creates ./.venv (uv), installs "freetoken[accel]" (FT_VERSION), verifies the
CUDA 13 toolchain, and runs 'ft bench bw' once. --force reinstalls into the venv;
--skip-cuda-check bypasses the nvcc/driver gate; --no-bench skips calibration.
EOF
            exit 0 ;;
        *) printf 'Unknown argument: %s\n' "$arg" >&2; exit 1 ;;
    esac
done

log() { printf '\033[33m%s\033[0m\n' "$*"; }

# --- 1/5 platform + CUDA gate ----------------------------------------------
log "[1/5] Checking runtime prerequisites..."
if [[ "$(uname -s)" != "Linux" ]]; then
    printf 'ERROR: FreeToken has Linux-only wheels. On hermine this must run in WSL2, not native Windows.\n' >&2
    exit 1
fi
if ! command -v uv >/dev/null 2>&1; then
    printf 'ERROR: uv not found. Install it: https://docs.astral.sh/uv/\n' >&2
    exit 1
fi
if ! command -v nvidia-smi >/dev/null 2>&1; then
    printf 'ERROR: nvidia-smi not found — no NVIDIA driver visible in this WSL distro.\n' >&2
    exit 1
fi
printf '  driver: %s\n' "$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1)"

if [[ "$SKIP_CUDA_CHECK" != "1" ]]; then
    # nvcc/CUDA_HOME: the venv install and `ft serve` init both work without it
    # (measured 2026-08-25), but the offload PCIe-gather kernel needs a CUDA 13
    # toolkit to JIT — `ft bench bw` reports "Could not find CUDA installation".
    # So this is a strong WARNING, not a hard stop.
    if ! command -v nvcc >/dev/null 2>&1; then
        cat >&2 <<'EOF'
WARNING: nvcc / CUDA_HOME not found. Install/verify works without it, but the
offload PCIe-gather kernel needs a CUDA 13 toolkit at runtime. Install in WSL:

  wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
  sudo dpkg -i cuda-keyring_1.1-1_all.deb
  sudo apt-get update && sudo apt-get install -y cuda-toolkit-13-0
  echo 'export CUDA_HOME=/usr/local/cuda-13.0' >> ~/.bashrc
  echo 'export PATH=$CUDA_HOME/bin:$PATH' >> ~/.bashrc && source ~/.bashrc
EOF
    else
        printf '  nvcc: %s\n' "$(nvcc --version | sed -n 's/.*release \([0-9.]*\).*/\1/p' | head -n1)"
    fi

    # memlock: FreeToken's offload backend cudaHostRegister's the expert banks
    # (pin-after-fill; no pageable fallback is implemented). WSL defaults memlock
    # to 64 MB (soft AND hard), so pinning ~0.2 GiB banks fails and the load dies
    # with "cudaHostRegister failed" (measured 2026-08-25). Raising it needs root.
    memlock_kb="$(ulimit -l)"
    if [[ "$memlock_kb" != "unlimited" ]] && (( memlock_kb < 1048576 )); then
        cat >&2 <<EOF
WARNING: memlock limit is ${memlock_kb} KB — too low to pin the offload expert
banks; serving a MoE will die with "cudaHostRegister failed". Raise it (root):

  echo '* soft memlock unlimited' | sudo tee -a /etc/security/limits.conf
  echo '* hard memlock unlimited' | sudo tee -a /etc/security/limits.conf

Then open a NEW WSL shell (or 'wsl --shutdown' from Windows and reopen) and check
'ulimit -l' shows 'unlimited'.
EOF
    else
        printf '  memlock: %s KB\n' "$memlock_kb"
    fi
fi

# --- 2/5 venv --------------------------------------------------------------
log "[2/5] Creating venv (uv) at .venv ..."
if [[ ! -d "$VENV_DIR" || "$FORCE" == "1" ]]; then
    uv venv "$VENV_DIR"
else
    printf '  venv exists — reusing (use --force to recreate)\n'
fi

# --- 3/5 install -----------------------------------------------------------
log "[3/5] Installing freetoken[accel] ..."
SPEC="freetoken[accel]"
[[ "$FT_VERSION" != "latest" ]] && SPEC="freetoken[accel]==$FT_VERSION"
UPGRADE=()
[[ "$FT_VERSION" == "latest" ]] && UPGRADE=(--upgrade)
uv pip install --python "$PY" "${UPGRADE[@]}" "$SPEC"

# --- 4/5 verify ------------------------------------------------------------
log "[4/5] Verifying ft ..."
[[ -x "$FT" ]] || { printf 'ERROR: ft not found in venv after install: %s\n' "$FT" >&2; exit 1; }
"$FT" --version

# --- 5/5 bench bw ----------------------------------------------------------
if [[ "$NO_BENCH" == "1" ]]; then
    log "[5/5] Skipping 'ft bench bw' (--no-bench)."
else
    local_profile_dir="$HOME/.cache/freetoken/benchbw"
    if [[ "$FORCE" != "1" ]] && ls "$local_profile_dir"/*.json >/dev/null 2>&1; then
        log "[5/5] bench bw profile already present — skipping (use --force to re-run)."
    else
        log "[5/5] Calibrating MoE backend ('ft bench bw', once per GPU)..."
        "$FT" bench bw || printf 'WARNING: ft bench bw failed — auto backend falls back to offload.\n' >&2
    fi
fi

log "Done. Serve a model with: ./server.sh"
