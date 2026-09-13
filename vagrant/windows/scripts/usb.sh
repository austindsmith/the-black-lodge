#!/usr/bin/env bash
# Host-side helpers for the kit USB stick, found by its filesystem label.
#   usb.sh ids <label>      print "<vendor> <product>"; exit 1 if absent or not USB
#   usb.sh release <label>  unmount the stick's partitions so QEMU can take it over
#   usb.sh xml <label>      libvirt <hostdev> XML, for `virsh attach-device`
set -euo pipefail

cmd=${1:?usage: usb.sh ids|release|xml <label>}
label=${2:?usage: usb.sh ids|release|xml <label>}
dev=/dev/disk/by-label/$label

ids() {
  [[ -e $dev ]] || return 1
  local props
  props=$(udevadm info --query=property --name="$dev")
  # Never hand a disk to the guest just because it shares the label.
  if ! grep -qx 'ID_BUS=usb' <<<"$props"; then
    echo "usb.sh: $dev is not a USB device; not passing it through" >&2
    return 1
  fi
  echo "$(sed -n 's/^ID_VENDOR_ID=//p' <<<"$props") $(sed -n 's/^ID_MODEL_ID=//p' <<<"$props")"
}

case $cmd in
  ids)
    ids
    ;;
  release)
    if [[ ! -e $dev ]]; then
      echo "USB stick '$label' is not plugged in; the VM starts without it ('just usb-attach' later)."
      exit 0
    fi
    # QEMU detaches the whole device from the host, so unmount every partition on it.
    part=$(readlink -f "$dev")
    parent=$(lsblk -no PKNAME "$part")
    disk=${parent:+/dev/$parent}
    lsblk -rno PATH,MOUNTPOINT "${disk:-$part}" | while read -r path mountpoint; do
      if [[ -n $mountpoint ]]; then
        udisksctl unmount --block-device "$path"
      fi
    done
    ;;
  xml)
    found=$(ids) || { echo "usb.sh: USB stick '$label' not found" >&2; exit 1; }
    read -r vendor product <<<"$found"
    cat <<EOF
<hostdev mode='subsystem' type='usb'>
  <source>
    <vendor id='0x$vendor'/>
    <product id='0x$product'/>
  </source>
</hostdev>
EOF
    ;;
  *)
    echo "usb.sh: unknown command '$cmd'" >&2
    exit 2
    ;;
esac
