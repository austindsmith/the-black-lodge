# Cloudnative PG

### Initial password reset

```bash
kubectl exec -n cloudnative-pg app-cluster-1 -- \
  psql -U postgres -c "ALTER ROLE postgres PASSWORD 'your-strong-password'"
```
