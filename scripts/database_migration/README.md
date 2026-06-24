# Database Migration

Resetting postgres password manually (avoid)

```bash
kubectl exec -n cloudnative-pg -it app-cluster-1 -- \
  psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'NEWPASSWORD';"
```

Disabling an app by scaling to 0:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: sonarr
  namespace: media
spec:
  values:
    replicaCount: 0
```
