# shellcheck shell=bash
#
# config-load.sh — resolve FT_* settings for the FreeToken bash tooling.
# Source it, don't execute it:  source "$SCRIPT_DIR/config-load.sh"
#
# Precedence, strongest first: an exported env var, config.env, config.env.example.
# The .example must come last — it assigns values unconditionally and would
# otherwise clobber an exported value.
#
# Unlike llama.cpp/config-load.sh there is no config.ps1 branch: FreeToken ships
# Linux-only wheels (manylinux, triton gated to platform_system=="Linux"), so the
# only supported runtime on hermine is WSL2. There is no native-Windows path to
# configure. config.env.example still gets the CRLF strip because it may be edited
# on the Windows side of the checkout.

_ft_source_cfg() {
    local f="$1" tmp
    tmp="$(mktemp)"
    tr -d '\r' < "$f" > "$tmp"
    # shellcheck disable=SC1090
    source "$tmp"
    rm -f "$tmp"
}

_ft_load_config() {
    local dir="$1"
    # Preserve exported overrides so the file cannot clobber them.
    local env_models_dir="${FT_MODELS_DIR:-}" env_preset="${FT_PRESET:-}" env_model="${FT_MODEL:-}"

    if [[ -f "$dir/config.env" ]]; then
        _ft_source_cfg "$dir/config.env"
    elif [[ -f "$dir/config.env.example" ]]; then
        printf 'config.env not found — using defaults from config.env.example\n' >&2
        _ft_source_cfg "$dir/config.env.example"
    fi

    [[ -n "$env_models_dir" ]] && FT_MODELS_DIR="$env_models_dir"
    [[ -n "$env_preset" ]] && FT_PRESET="$env_preset"
    [[ -n "$env_model" ]] && FT_MODEL="$env_model"
    return 0
}
