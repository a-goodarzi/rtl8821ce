#!/bin/bash
#
# Fork-local helper, not part of upstream. Show which 8821ce driver is
# currently active: this repo's out-of-tree (DKMS) driver, or the
# in-kernel rtw88_8821ce driver.
#
# Usage:
#   ./which-driver.sh

set -euo pipefail

OOT_MOD="8821ce"
INTREE_MOD="rtw88_8821ce"

lsmod_out="$(lsmod)"

current="none"
if grep -q "^${OOT_MOD}\b" <<<"$lsmod_out"; then
	current="oot"
elif grep -q "^${INTREE_MOD}\b" <<<"$lsmod_out"; then
	current="intree"
fi

case "$current" in
	oot)     echo "Active driver: out-of-tree ($OOT_MOD, this repo's DKMS module)" ;;
	intree)  echo "Active driver: in-kernel ($INTREE_MOD)" ;;
	none)    echo "Active driver: none loaded" ;;
esac

echo "---"
echo "Loaded wireless modules:"
lsmod | grep -E "^(rtw88|${OOT_MOD})" || echo "(none matched)"

echo "---"
echo "Wireless interfaces and drivers:"
found=0
for dev in /sys/class/net/*; do
	iface="$(basename "$dev")"
	if [[ -e "$dev/device/driver" ]]; then
		drv="$(basename "$(readlink -f "$dev/device/driver")")"
		if [[ "$drv" == "$OOT_MOD" || "$drv" == "$INTREE_MOD" || "$iface" == wl* ]]; then
			echo "$iface -> $drv"
			found=1
		fi
	fi
done
if [[ $found -eq 0 ]]; then
	echo "(no wireless interfaces found)"
fi
