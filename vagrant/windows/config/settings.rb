require "shellwords"

# Host-side settings; override with environment variables (e.g. in ../.envrc).
module Settings
  BOX = ENV.fetch("KIT_BOX", "gusztavvargadr/windows-10")
  BOX_VERSION = ENV.fetch("KIT_BOX_VERSION", "2511.0.0")
  # Filesystem label of the USB stick. Use exFAT or NTFS so Windows can mount it.
  USB_LABEL = ENV.fetch("KIT_USB_LABEL", "portable")

  # Last commit touching dir, "-dirty" if it has uncommitted changes. Stamped into
  # the stick's dist.json so every build traces back to a commit.
  def self.revision(dir)
    git = "git -C #{dir.shellescape}"
    sha = `#{git} log -1 --format=%h -- . 2>/dev/null`.strip
    return "unknown" if sha.empty?

    dirty = !`#{git} status --porcelain -- . 2>/dev/null`.strip.empty?
    dirty ? "#{sha}-dirty" : sha
  end

  # Host git identity, so commits made in the builder (dotfiles sketching) are yours.
  def self.git_identity
    %w[user.name user.email].map { |key| `git config --get #{key}`.strip }
  end
end
