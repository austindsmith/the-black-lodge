module SharedFolders
  def self.configure(config)
    config.vm.synced_folder ".", "/vagrant", disabled: true

    dotfiles_path = ENV.fetch("WINDOWS_DOTFILES_PATH")

    config.vm.synced_folder dotfiles_path, "/cygdrive/C/dotfiles",
      type: "rsync",
      rsync__args: ["--verbose", "--archive", "--delete", "--copy-links", "--no-owner", "--no-group", "--blocking-io"],
      rsync__auto: true,
      create: true
  end
end
