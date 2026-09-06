#!/bin/bash
#
# Fork-local helper, not part of upstream. Hot-swap between the in-kernel
# rtw88_8821ce driver and this repo's out-of-tree 8821ce (DKMS) driver,
# without needing a reboot.
#
# Usage:
#   sudo ./toggle-driver.sh            # toggle to whichever isn't active
#   sudo ./toggle-driver.sh oot        # force the out-of-tree driver
#   sudo ./toggle-driver.sh intree     # force the in-kernel driver

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
	echo "You must run this with superuser privileges. Try \"sudo ./toggle-driver.sh\"" >&2
	exit 1
fi

OOT_MOD="8821ce"
INTREE_MOD="rtw88_8821ce"
BLACKLIST_FILE="/etc/modprobe.d/blacklist-rtw88.conf"

current="none"
if lsmod | grep -q "^${OOT_MOD}\b"; then
	current="oot"
elif lsmod | grep -q "^${INTREE_MOD}\b"; then
	current="intree"
fi

target="${1:-}"
if [[ -z "$target" ]]; then
	case "$current" in
		oot) target="intree" ;;
		intree) target="oot" ;;
		none) target="oot" ;;
	esac
fi

if [[ "$target" != "oot" && "$target" != "intree" ]]; then
	echo "Usage: $0 [oot|intree]" >&2
	exit 1
fi

echo "Currently loaded: $current"
echo "Switching to:     $target"

# Find the wifi interface (if any) so we can bring it down cleanly first.
iface=""
for dev in /sys/class/net/*; do
	if [[ -e "$dev/device/driver" ]]; then
		drv="$(basename "$(readlink -f "$dev/device/driver")")"
		if [[ "$drv" == "$OOT_MOD" || "$drv" == "$INTREE_MOD" ]]; then
			iface="$(basename "$dev")"
			break
		fi
	fi
done

if [[ -n "$iface" ]]; then
	echo "Bringing down interface: $iface"
	ip link set "$iface" down 2>/dev/null || true
fi

if [[ "$current" == "oot" ]]; then
	echo "Unloading $OOT_MOD..."
	modprobe -r "$OOT_MOD"
elif [[ "$current" == "intree" ]]; then
	echo "Unloading $INTREE_MOD..."
	modprobe -r "$INTREE_MOD"
fi

if [[ "$target" == "oot" ]]; then
	echo "blacklist $INTREE_MOD" > "$BLACKLIST_FILE"
	echo "Loading $OOT_MOD..."
	modprobe "$OOT_MOD"
else
	rm -f "$BLACKLIST_FILE"
	echo "Loading $INTREE_MOD..."
	modprobe "$INTREE_MOD"
fi

sleep 1
echo "---"
echo "Loaded wireless modules:"
lsmod | grep -E "^(rtw88|${OOT_MOD})" || echo "(none matched)"
echo "---"
echo "Wireless interfaces:"
ip -brief link show 2>/dev/null | grep -iE "wl" || echo "(none found yet, may take a moment to reappear)"
