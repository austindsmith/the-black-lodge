# The Black Lodge

## Reference

- [HashiCorp Boot Commands](https://developer.hashicorp.com/packer/docs/builders/virtualbox/iso#boot-command)
- [Makefile Tutorial](https://makefiletutorial.com/)
- [Just Files](https://github.com/casey/just) - Useful for saving hard to remember commands.k3d
- [Just Files Manual](https://just.systems/man/en/)

## NAS

### nfsv4

- With nfsv4, mounting will work with LDAP/username. Just ensure that users in the FreeIPA domain have permissions to the shared folder. Then they can be mounted without squashing.

### Shared folders

- [ ] Migrate `infrastructure`
- [ ] Rename `paperless` to `paperless-ngx`
- [ ] Break infrastructure into `kubernetes` and `proxmox` and eliminate `docker`.

## Autodocs

- Sphinx
- dbt
- Dagster
- Terraform docs
- Ansible docs
- Helm docs
- GitHub actions docs
- Rego (policies as code)

## Snippets

### Generating a `$6$` hash

```bash
openssl passwd -6 'PASSWORD_HERE'
```

### Append a new key to age keys file

```bash
age-keygen >> ~/.config/sops/age/keys.txt
```

### Encrypt a file with SOPS and age

.auto is used for auto-detection of pkvars files when running `packer build`

```bash
sops -e packer/ubuntu-2404/secrets.auto.pkrvars.hcl > packer/ubuntu-2404/secrets.auto.pkrvars.hcl.enc
```

### Creating Packer golden image

```bash
packer init packer/ubuntu-2404
packer build packer/ubuntu-2404
```

### Creating Pangolin secret

```
kubectl create secret generic newt -n pangolin --from-env-file=newt.env
```
