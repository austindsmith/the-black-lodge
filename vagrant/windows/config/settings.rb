require "shellwords"

module Settings
  ROOT = File.expand_path("..", __dir__)
  KIT_DIR = File.join(ROOT, "kit")

  BOX = ENV.fetch("KIT_BOX", "gusztavvargadr/windows-10")
  BOX_VERSION = ENV.fetch("KIT_BOX_VERSION", "2511.0.0")
  USB_LABEL = ENV.fetch("KIT_USB_LABEL", "portable")

  BUILDER_CPUS = Integer(ENV.fetch("KIT_BUILDER_CPUS", 4))
  BUILDER_MEMORY_MB = Integer(ENV.fetch("KIT_BUILDER_MEMORY_MB", 8192))
  BUILDER_WINRM_TIMEOUT = Integer(ENV.fetch("KIT_BUILDER_WINRM_TIMEOUT", 7200))

  OFFLINE_NETWORK_NAME = "kit-offline"
  OFFLINE_NETWORK_ADDRESS = "192.168.124.0/24"

  def self.kit_revision
    git = "git -C #{KIT_DIR.shellescape}"
    sha = `#{git} log -1 --format=%h -- . 2>/dev/null`.strip
    return "unknown" if sha.empty?

    dirty = !`#{git} status --porcelain -- . 2>/dev/null`.strip.empty?
    dirty ? "#{sha}-dirty" : sha
  end

  def self.git_identity
    %w[user.name user.email].map { |key| `git config --get #{key}`.strip }
  end
end
