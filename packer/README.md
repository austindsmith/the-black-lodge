# Packer

## Commands

Passing a var file path, can be used multiple times. Needed for including var files outside of the folder of the `pkr.hcl`. Note that --var-file order impacts the order of implementation. Here, `ubuntu.pkrvars.hcl` will override anything in `shared.pkvars.hcl` if there are any conflicting variables set.

```zsh
packer build \
  -var-file=shared.pkrvars.hcl \
  -var-file=ubuntu.pkrvars.hcl \
  .
```

## Cloud images

- [Rocky Linux](https://download.rockylinux.org/pub/rocky/)
- [Ubuntu](https://cloud-images.ubuntu.com/)