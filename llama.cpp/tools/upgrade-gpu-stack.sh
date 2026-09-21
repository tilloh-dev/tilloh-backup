#!/usr/bin/env bash
# upgrade-gpu-stack.sh [stufe1|stufe2] — GPU-Stack aus bookworm-backports aktualisieren.
#
#   stufe1  Mesa/RADV + libdrm   (Userspace, kein Neustart, sofort messbar)
#   stufe2  AMD-Firmware + Kernel 6.12 (braucht Neustart)
#
# Zwei Stufen, damit der Gewinn sauber zuzuordnen ist.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Bitte mit sudo ausfuehren." >&2; exit 1; }
STUFE="${1:-stufe1}"
LIST=/etc/apt/sources.list.d/bookworm-backports.list

if [[ ! -f $LIST ]]; then
    echo ">> bookworm-backports eintragen"
    echo 'deb http://deb.debian.org/debian bookworm-backports main contrib non-free-firmware' > "$LIST"
else
    echo ">> bookworm-backports bereits eingetragen"
fi
# Backports haben Pin-Prioritaet 100: nichts wird automatisch hochgezogen,
# nur was unten mit -t explizit angefordert wird.
apt-get update

case "$STUFE" in
  stufe1)
    echo ">> Mesa/RADV + libdrm aus backports"
    apt-get install -y -t bookworm-backports \
        mesa-vulkan-drivers libdrm2 libdrm-amdgpu1 libdrm-common
    echo
    echo ">> Ergebnis:"
    dpkg-query -W -f='  mesa-vulkan-drivers ${Version}\n' mesa-vulkan-drivers
    dpkg-query -W -f='  libdrm2             ${Version}\n' libdrm2
    echo
    echo ">> Kein Neustart noetig. Jetzt messen:"
    echo "   tools/gpu-bench.sh nachher-mesa25"
    ;;
  stufe2)
    echo ">> AMD-Firmware + Kernel 6.12 aus backports"
    apt-get install -y -t bookworm-backports \
        firmware-amd-graphics linux-image-amd64 linux-headers-amd64
    echo
    dpkg-query -W -f='  firmware-amd-graphics ${Version}\n' firmware-amd-graphics
    echo
    echo ">> NEUSTART noetig, danach messen:"
    echo "   tools/gpu-bench.sh nachher-kernel612"
    ;;
  *) echo "Unbekannte Stufe: $STUFE (stufe1|stufe2)" >&2; exit 1 ;;
esac
