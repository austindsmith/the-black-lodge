#!/usr/bin/env bash
set -euo pipefail

label=${1:-${KIT_USB_LABEL:-portable}}
device=/dev/disk/by-label/$label

[[ -e $device ]] || {
    echo "stick: '$label' is not plugged in" >&2
    exit 1
}

resolved=$(readlink -f "$device")
mountpoint=$(findmnt -nro TARGET --source "$resolved" | head -1)
if [[ -z $mountpoint ]]; then
    udisksctl mount --block-device "$device" >/dev/null
    mountpoint=$(findmnt -nro TARGET --source "$resolved" | head -1)
fi

dist=$mountpoint/kit/dist.json
[[ -f $dist ]] || {
    echo "stick: no kit on '$label' yet; run 'just builder'" >&2
    exit 1
}

jq -r '"kit revision: \(.revision)\ndotfiles:     \(.dotfiles)\nbuilt:        \(.built)"' "$dist"
printf 'size:         %s\n' "$(du -sh "$mountpoint/kit" | cut -f1)"
echo 'apps:'
jq -r '.components | to_entries[] | select(.value.app) | "  \(.value.app.name) \(.value.app.version)"' "$dist" | sort
