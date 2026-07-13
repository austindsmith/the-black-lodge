# Vagrant

- [Vagrant docs](https://developer.hashicorp.com/vagrant/docs)
- [Vagrant libvirt provider](https://github.com/vagrant-libvirt/vagrant-libvirt)
- [Public Vagrant box listings](https://portal.cloud.hashicorp.com/vagrant/discover)

## Todo

- [ ] Add Spice to virt-manager to replace VNC

## Commands

Installing libvirt plugin

```zsh
vagrant plugin install vagrant-libvirt
```

Bringing up vm (`cd` into same directory as the `Vagrantfile`)

```zsh
vagrant up
```

Remove vm (`cd` into same directory as the `Vagrantfile`)

```zsh
vagrant destroy
```

## Deployment options

- Docker
- VirtualBox
- libvirt
- AWS/Azure/Google Cloud
- LXC/Proxmox
