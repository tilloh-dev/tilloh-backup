#!/usr/bin/env bash
#
# bootstrap.sh — install a prebuilt Vulkan llama.cpp into ./vendor
#
# Linux/Pop!_OS adaptation of countzero/windows_llama.cpp's rebuild_llama.cpp.ps1:
# instead of compiling, fetch the official prebuilt Vulkan release tarball.
# No compiler, no CMake, no conda.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- load config -----------------------------------------------------------
# shellcheck source=config-load.sh
source "$SCRIPT_DIR/config-load.sh"
_llama_load_config "$SCRIPT_DIR"

LLAMA_VERSION="${LLAMA_VERSION:-latest}"
VENDOR_DIR="$SCRIPT_DIR/vendor/llama.cpp"
CACHE_DIR="$SCRIPT_DIR/cache"
MARKER="$SCRIPT_DIR/vendor/.llama-version"

# --- args ------------------------------------------------------------------
FORCE=0
for arg in "$@"; do
    case "$arg" in
        -f|--force) FORCE=1 ;;
        -h|--help)
            cat <<EOF
Usage: bootstrap.sh [--force]

Installs the prebuilt Vulkan llama.cpp release defined by LLAMA_VERSION
(config.env) into ./vendor/llama.cpp. Use --force to reinstall the same tag.
EOF
            exit 0 ;;
        *) printf 'Unknown argument: %s\n' "$arg" >&2; exit 1 ;;
    esac
done

# --- helpers ---------------------------------------------------------------
log() { printf '\033[33m%s\033[0m\n' "$*"; }

# libcurl went through Ubuntu's 64-bit-time_t rename: 24.04 and newer ship
# libcurl4t64, older releases libcurl4. Asking for the wrong one made
# install_apt_deps report a permanently missing package on every run.
pick_libcurl() {
    local alt
    for alt in libcurl4t64 libcurl4; do
        dpkg -s "$alt" >/dev/null 2>&1 && { printf '%s' "$alt"; return; }
    done
    for alt in libcurl4t64 libcurl4; do
        apt-cache show "$alt" >/dev/null 2>&1 && { printf '%s' "$alt"; return; }
    done
}

install_apt_deps() {
    local deps=(curl ca-certificates tar jq libvulkan1 mesa-vulkan-drivers vulkan-tools libgomp1)
    local libcurl_pkg; libcurl_pkg="$(pick_libcurl)"
    [[ -n "$libcurl_pkg" ]] && deps+=("$libcurl_pkg")
    local missing=() pkg
    for pkg in "${deps[@]}"; do
        dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        printf '  all dependencies present\n'
        return
    fi
    # The bash tool shell is non-interactive, so a password prompt cannot be
    # answered here — say what to run instead of dying on sudo's prompt.
    if ! sudo -n true 2>/dev/null; then
        printf 'ERROR: missing packages need sudo: %s\n' "${missing[*]}" >&2
        printf '       run: sudo apt-get update && sudo apt-get install -y %s\n' "${missing[*]}" >&2
        exit 1
    fi
    printf '  installing: %s\n' "${missing[*]}"
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
}

# Upstream changed its release scheme on 2026-08-25: the semver "stable"
# releases (v0.3.0, ...) that GitHub reports as /releases/latest carry no
# binaries at all -- only a nightly-tag.txt asset naming the b<NNNNN> nightly
# whose tarballs belong to them. The tarballs themselves sit on those
# nightlies, and those are all flagged prerelease, so they never show up as
# "latest". Hence: resolve a non-nightly tag through its nightly-tag.txt, and
# fall back to the newest nightly that actually carries the asset we need.
GH_API='https://api.github.com/repos/ggml-org/llama.cpp'
GH_DL='https://github.com/ggml-org/llama.cpp/releases/download'

resolve_tag() {
    if [[ "$LLAMA_VERSION" != "latest" ]]; then
        curl -fsSL "$GH_API/releases/latest" 2>/dev/null | jq -r '.tag_name // empty' || true
    else
        printf '%s' "$LLAMA_VERSION"
        return
    fi

    # ggml-org publishes the per-commit build tags (b<number>) that carry the
    # binaries as *prereleases*. /releases/latest therefore returns a version
    # tag (e.g. v0.3.0) whose only asset is nightly-tag.txt — a pointer to the
    # build tag that does have the tarballs. Follow that pointer.
    local api='https://api.github.com/repos/ggml-org/llama.cpp'
    local latest tag
    latest="$(curl -fsSL "$api/releases/latest" 2>/dev/null | jq -r '.tag_name // empty' || true)"
    if [[ "$latest" =~ ^b[0-9]+$ ]]; then printf '%s' "$latest"; return; fi

    if [[ -n "$latest" ]]; then
        tag="$(curl -fsSL "https://github.com/ggml-org/llama.cpp/releases/download/$latest/nightly-tag.txt" 2>/dev/null | tr -dc 'a-z0-9' || true)"
        if [[ "$tag" =~ ^b[0-9]+$ ]]; then printf '%s' "$tag"; return; fi
    fi

    # Fallback: newest prerelease whose tag looks like a build tag.
    curl -fsSL "$api/releases?per_page=20" 2>/dev/null \
        | jq -r '[.[] | select(.tag_name | test("^b[0-9]+$"))][0].tag_name // empty' || true
}

nightly_pointer() {   # <tag> -> b-tag named by that release's nightly-tag.txt
    curl -fsSL "$GH_DL/$1/nightly-tag.txt" 2>/dev/null | tr -d '[:space:]' || true
}

newest_nightly_with_asset() {   # <arch> -> newest release carrying our tarball
    curl -fsSL "$GH_API/releases?per_page=30" 2>/dev/null \
        | jq -r --arg a "$1" '[.[] | select([.assets[].name]
            | any(endswith("-bin-ubuntu-vulkan-" + $a + ".tar.gz")))][0].tag_name // empty' \
        || true
}

release_has_asset() {   # <tag> <asset-name>
    curl -fsSL "$GH_API/releases/tags/$1" 2>/dev/null \
        | jq -e --arg n "$2" 'any(.assets[]; .name == $n)' >/dev/null 2>&1
}

detect_arch() {
    case "$(uname -m)" in
        x86_64)        printf 'x64' ;;
        aarch64|arm64) printf 'arm64' ;;
        *) printf 'ERROR: unsupported architecture: %s\n' "$(uname -m)" >&2; exit 1 ;;
    esac
}

# --- run -------------------------------------------------------------------
log "[1/5] Installing APT runtime dependencies..."
install_apt_deps

log "[2/5] Resolving llama.cpp release..."
ARCH="$(detect_arch)"
TAG="$(resolve_tag)"
[[ -n "$TAG" && "$TAG" != "null" ]] || { printf 'ERROR: could not resolve release tag\n' >&2; exit 1; }

# A stable tag ships no tarballs; follow the nightly it points at.
if [[ ! "$TAG" =~ ^b[0-9]+$ ]]; then
    POINTER="$(nightly_pointer "$TAG")"
    if [[ "$POINTER" =~ ^b[0-9]+$ ]]; then
        printf '  %s ships no binaries; its nightly-tag.txt names %s\n' "$TAG" "$POINTER"
        TAG="$POINTER"
    fi
fi

ASSET="llama-${TAG}-bin-ubuntu-vulkan-${ARCH}.tar.gz"
if ! release_has_asset "$TAG" "$ASSET"; then
    FALLBACK="$(newest_nightly_with_asset "$ARCH")"
    [[ -n "$FALLBACK" ]] || {
        printf 'ERROR: no llama.cpp release found carrying %s\n' "$ASSET" >&2; exit 1; }
    printf '  %s carries no %s; using newest nightly %s instead\n' "$TAG" "$ASSET" "$FALLBACK"
    TAG="$FALLBACK"
    ASSET="llama-${TAG}-bin-ubuntu-vulkan-${ARCH}.tar.gz"
fi

URL="$GH_DL/${TAG}/${ASSET}"
printf '  version=%s  arch=%s\n' "$TAG" "$ARCH"

if [[ "$FORCE" != "1" && -f "$MARKER" && "$(cat "$MARKER")" == "$TAG" ]] \
   && find "$SCRIPT_DIR/vendor" -name llama-server -type f -print -quit 2>/dev/null | grep -q .; then
    log "[3/5] Already installed ($TAG) — skipping download (use --force to reinstall)."
else
    log "[3/5] Downloading + extracting $ASSET ..."
    mkdir -p "$CACHE_DIR"
    curl -L --fail -C - -o "$CACHE_DIR/$ASSET" "$URL"
    rm -rf "$VENDOR_DIR"
    mkdir -p "$VENDOR_DIR"
    tar -xzf "$CACHE_DIR/$ASSET" -C "$VENDOR_DIR"
    printf '%s' "$TAG" > "$MARKER"
fi

log "[4/5] Locating binaries..."
BIN_PATH="$(find "$SCRIPT_DIR/vendor" -name llama-server -type f 2>/dev/null | head -n1)"
[[ -n "$BIN_PATH" ]] || { printf 'ERROR: llama-server not found after extraction\n' >&2; exit 1; }
BIN_DIR="$(dirname "$BIN_PATH")"
chmod +x "$BIN_DIR"/llama-* 2>/dev/null || true
printf '  bin dir: %s\n' "$BIN_DIR"

log "[5/5] Verifying..."
if ! LD_LIBRARY_PATH="$BIN_DIR:${LD_LIBRARY_PATH:-}" "$BIN_PATH" --version; then
    printf 'ERROR: llama-server failed to run (possible glibc mismatch — see README troubleshooting)\n' >&2
    exit 1
fi
if command -v vulkaninfo >/dev/null 2>&1; then
    if vulkaninfo --summary >/dev/null 2>&1; then
        printf '  Vulkan: OK (GPU visible)\n'
    else
        printf '  WARNING: vulkaninfo found no usable GPU; llama.cpp will fall back to CPU\n' >&2
    fi
fi

log "Done. Start the server with: ./server.sh"
