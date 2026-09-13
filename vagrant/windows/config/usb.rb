require "open3"

# Passes the kit USB stick (found by filesystem label) through to the guest as a real
# USB device, so Windows mounts it exactly like a stick plugged into the work laptop.
module Usb
  SCRIPT = File.expand_path("../scripts/usb.sh", __dir__)

  # [vendor, product] of the stick, or nil when it isn't plugged in.
  def self.ids(label)
    out, status = Open3.capture2(SCRIPT, "ids", label)
    status.success? ? out.split : nil
  end

  def self.configure(config, label)
    config.vm.provider :libvirt do |libvirt|
      libvirt.usb_controller model: "qemu-xhci"
      vendor, product = ids(label)
      if vendor
        # optional: the domain still boots if the stick is missing on a later `up`.
        libvirt.usb vendor: "0x#{vendor}", product: "0x#{product}", startupPolicy: "optional"
      end
    end

    # QEMU takes the device away from the host kernel; unmount it first so no
    # pending writes are lost and the host doesn't hold a stale mount.
    config.trigger.before [:up, :reload] do |trigger|
      trigger.name = "Release USB stick '#{label}'"
      trigger.run = { path: SCRIPT, args: ["release", label] }
    end
  end
end
