module Bootstrap
  def self.configure(config)
    config.vm.provision "shell",
      name: "bootstrap",
      path: "./provision/bootstrap.ps1"
  end
end
