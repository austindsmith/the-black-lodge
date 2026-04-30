# The Black Lodge

## Reference

- [HashiCorp Boot Commands](https://developer.hashicorp.com/packer/docs/builders/virtualbox/iso#boot-command)
- [Makefile Tutorial](https://makefiletutorial.com/)
- [Just Files](https://github.com/casey/just)

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