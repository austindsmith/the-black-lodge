# Database Migration

### Reference

[Arr Guide](https://wiki.servarr.com/sonarr/postgres-setup)

Resetting postgres password manually (avoid)

```bash
kubectl exec -n cloudnative-pg -it app-cluster-1 -- \
  psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'NEWPASSWORD';"
```

Disabling an app by scaling to 0:

```bash
kubectl scale deployment sonarr -n media --replicas=0
```

Remove starting configs

```bash
DELETE FROM "QualityProfiles";
DELETE FROM "QualityDefinitions";
DELETE FROM "DelayProfiles";
DELETE FROM "Metadata";
DELETE FROM "Config";
DELETE FROM "VersionInfo";
DELETE FROM "ScheduledTasks";
```

Run load conf

```bash
pgloader sonarr.conf
```

Enable an app by scaling to 1:

```bash
kubectl scale deployment sonarr -n media --replicas=1
```
