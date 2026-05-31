# Authentik

## Commands

### Generating an application primary key

```bash
python3 -c "import uuid; print(uuid.uuid5(uuid.NAMESPACE_DNS, 'headlamp.theblacklodge.dev'))"
```

or

```bash
python3 -c "import uuid; print(uuid.uuid5(uuid.NAMESPACE_DNS, 'Provider for Pangolin'))"
```

### Generating client id

```bash
pass-cli password generate random --length 40 --symbols false | clip
```

### Generating client secret

```bash
pass-cli password generate random --length 128 --symbols false | clip
```
