#!/usr/bin/env bash
set -euo pipefail

command=${1:?usage: usb.sh ids|release|xml <label>}
label=${2:?usage: usb.sh ids|release|xml <label>}
device=/dev/disk/by-label/$label

device_ids() {
    [[ -e $device ]] || return 1

    local properties
    properties=$(udevadm info --query=property --name="$device")
    if ! grep -qx 'ID_BUS=usb' <<<"$properties"; then
        echo "usb.sh: $device is not a USB device, refusing to pass it through" >&2
        return 1
    fi

    echo "$(sed -n 's/^ID_VENDOR_ID=//p' <<<"$properties") $(sed -n 's/^ID_MODEL_ID=//p' <<<"$properties")"
}

unmount_all_partitions() {
    local partition parent disk path mountpoint

    partition=$(readlink -f "$device")
    parent=$(lsblk -no PKNAME "$partition")
    disk=${parent:+/dev/$parent}

    lsblk -rno PATH,MOUNTPOINT "${disk:-$partition}" | while read -r path mountpoint; do
        if [[ -n $mountpoint ]]; then
            udisksctl unmount --block-device "$path"
        fi
    done
}

print_hostdev_xml() {
    local ids vendor product

    ids=$(device_ids) || {
        echo "usb.sh: USB stick '$label' not found" >&2
        exit 1
    }
    read -r vendor product <<<"$ids"

    cat <<XML
<hostdev mode='subsystem' type='usb'>
  <source>
    <vendor id='0x$vendor'/>
    <product id='0x$product'/>
  </source>
</hostdev>
XML
}

case $command in
    ids)
        device_ids
        ;;
    release)
        if [[ ! -e $device ]]; then
            echo "USB stick '$label' is not plugged in; the VM starts without it (attach later with 'just usb-attach')"
            exit 0
        fi
        unmount_all_partitions
        ;;
    xml)
        print_hostdev_xml
        ;;
    *)
        echo "usb.sh: unknown command '$command'" >&2
        exit 2
        ;;
esac
