#!/usr/bin/env bash
# gpu-bench.sh [label] — reproduzierbarer Vulkan-Referenzlauf für die 7900 XTX.
# Schreibt nach tools/bench-<label>.txt. Vorher/Nachher vergleichbar halten:
# immer dieselben Modelle, -p 512 -n 64 -r 3.
set -uo pipefail
LABEL="${1:-$(date +%Y%m%d-%H%M%S)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$(find -L "$HERE/../vendor" -name llama-bench -type f | head -n1)"
export LD_LIBRARY_PATH="$(dirname "$BIN")"
MODELS=/home/koester/.local/share/llama.cpp/models/Qwen3.8-27B
OUT="$HERE/bench-$LABEL.txt"
{
  echo "=== $LABEL — $(date -Is) ==="
  echo "Kernel:   $(uname -r)"
  echo "Mesa:     $(dpkg-query -W -f='${Version}' mesa-vulkan-drivers 2>/dev/null)"
  echo "libdrm:   $(dpkg-query -W -f='${Version}' libdrm2 2>/dev/null)"
  echo "Firmware: $(dpkg-query -W -f='${Version}' firmware-amd-graphics 2>/dev/null)"
  echo "Loader:   $(dpkg-query -W -f='${Version}' libvulkan1 2>/dev/null)"
  echo "coopmat:  $(vulkaninfo 2>/dev/null | grep -c VK_KHR_cooperative_matrix) Treffer in vulkaninfo"
  echo
  echo "--- ggml-vulkan Gerätezeile (Marker: 'matrix cores') ---"
  timeout 120 "$BIN" -m "$MODELS/Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf" --device VULKAN0 -ngl 999 -p 0 -n 1 -r 1 2>&1 \
    | grep -E 'ggml_vulkan: [0-9]'
  echo
  # WICHTIG: pp und tg in GETRENNTEN Aufrufen messen. Laeuft ein pp-Test vorher
  # im selben Prozess, bricht das nachfolgende tg auf etwa die Haelfte ein
  # (gemessen 2026-09-21: tg64 allein 41.7 t/s, direkt nach pp512 nur 20.7 t/s).
  for M in Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp Qwen3.8-27B-UD-Q3_K_XL; do
    echo "--- $M: Prompt-Processing ---"
    timeout 900 "$BIN" -m "$MODELS/$M.gguf" --device VULKAN0 -ngl 999 -fa 1 -p 512 -n 0 -r 3 2>&1 | grep -E '^\| qwen'
    echo "--- $M: Token-Generierung ---"
    timeout 900 "$BIN" -m "$MODELS/$M.gguf" --device VULKAN0 -ngl 999 -fa 1 -p 0 -n 512 -r 3 2>&1 | grep -E '^\| qwen'
  done
} | tee "$OUT"
echo
echo "gespeichert: $OUT"
