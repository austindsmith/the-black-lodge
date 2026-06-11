# Teleport

## Commands

### Setting a password on a local user

```bash
kubectl exec -n teleport deploy/teleport -- tctl users reset austin
```

### Getting tokens for deploying to devices

```bash
kubectl exec -n teleport deploy/teleport-auth -- tctl tokens add --type=node --ttl=1h
kubectl exec -n teleport deploy/teleport-auth -- tctl status
```
