require "open3"

module Usb
  SCRIPT = File.expand_path("../scripts/usb.sh", __dir__)

  def self.device_ids(label)
    stdout, status = Open3.capture2(SCRIPT, "ids", label)
    status.success? ? stdout.split : nil
  end

  def self.configure(config, label)
    config.vm.provider :libvirt do |libvirt|
      libvirt.usb_controller model: "qemu-xhci"
      vendor, product = device_ids(label)
      if vendor
        libvirt.usb vendor: "0x#{vendor}", product: "0x#{product}", startupPolicy: "optional"
      end
    end

    config.trigger.before [:up, :reload] do |trigger|
      trigger.name = "Release USB stick '#{label}'"
      trigger.run = { path: SCRIPT, args: ["release", label] }
    end
  end
end
