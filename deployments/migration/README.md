# Migration

I currently have Docker running on a Netcup server on Ubuntu. I would like to rebuild using all the new technologies I've learned or improved at since the initial deployment such as Terraform, Packer, Ansible and Kubernetes. The goal is to make it as fully `GitOps` as humanly possible (Netcup requires some manual steps, may revisit cloud providers when renewal is closer, but Netcup was SO cheap at the time).

In addition, one of the nice things about a homelab is that there's no pressure to not blow things up. However, in any real world scenario, there will be pressure. I've created some imaginary pressure to help push me to do this cleanly with minimal (if any) downtime so that I improve that skill simultaneously.

> [!info] Important
> All the below assumes GitOps practices. So using Terraform, Packer, Ansible, Kubernetes, Atlas or any other new tools identified, unless doing so is some "hack" or is otherwise impossible/not supported. In those scenarios, create documentation regardless. Or perhaps a shell script.

## References

### Terraform

- [Modules](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
-

## Documentation

- [ ] Read a book on documenting architecture and then add to this list with its suggestions.
- [ ] Rebuild `the-docs-lodge.org` and `austinsmith.org` following `VaultCMS` in conjunction with the GitHub/GitLab/Cloudflare Terraform implementations below.
- [ ] `terraform-docs` for Terraform, `antsibull-docs` or `ansible-navigator` for Ansible.

## Packer

### Proxmox

- [x] Create template for Windows Server 2025 ✅ 2026-06-21
- [x] Create template for Rocky OS ✅ 2026-06-21
- [x] Create template for Alpine OS ✅ 2026-06-21
- [x] Create template for Ubuntu OS ✅ 2026-06-21

## Unifi

**Subnets are examples, not set in stone. Read a book first on proper design.**

Don't let this hold back progress, fine to migrate to target subnets later.

- [ ] Create subnets for:
  - [ ] Kubernetes
  - [ ] Management (iDrac, Proxmox, OPNSense, battery backups) 192.168.0.0/24
  - [ ] Infrastructure (Pihole, freeIPA, Synology NAS) 192.168.10.0/24
  - [ ] Servers (Docker containers/LXCs that aren't promoted to main cluster, Synology NAS, development VMs, game/media servers): 192.168.30.0/24
  - [ ] Guest devices 92.168.50.0/24
  - [ ] Trusted devices (Laptops, phones, desktops, Steam Deck, Playstation): 192.168.40.0/24
  - [ ] Security Cameras 192.168.70.0/24
  - [ ] Wireguard/VPN clients 192.168.80.0/24
  - [ ] IOT 192.168.60.0/24
- [ ] Wireless APs to support new subnets

## GitHub/GitLab

- [ ] Manage via Terraform. Just make sure to keep the `.git` files so history isn't lost.

## Cloudflare

- [ ] Import existing configurations into Terraform and utilize Terraform to cleanup.

## Ansible

### Organization

- [ ] As described above, projects will be created at new and better targeted grains. Ensure these are integrated with `Semaphore` scheduling and deployment in mind as well, and have a strategy for running things consistently for scenarios where `Semaphore` is not yet stood up (justfiles?). I would consider an LXC for `Semaphore`, but I prefer not dedicating a fixed amount of RAM on the Proxmox VM where it can be avoided (mind may change as items are successfully migrated).

### Security hardening

- [ ] Disable Password Authentication and root login
- [ ] Enable GSSAPIAuthentcation
- [ ] Set AuthorizedKeysCommand
- [ ] Restrict AllowGroups
- [ ] LoginGraceTime & MaxAuthTries
- [ ] Disable X11 and AllowAgent Forwards
- [ ] disably sync cookies, rp filters, dmesg_restrict, kptr_restrict, and core dumps
- [ ] bridge-nf-call-iptables = 1
- [ ] ip_forward = 1
- [ ] brnetlifer and overlay load
- [ ] zone defaults (drop or public with allow list)
- [ ] linux-audit
- [ ] auditd
- [ ] fail2ban (crowdstrike?)
- [ ] unattended-upgrades for security patches
- [ ] .etc.issues login banners
- [ ] disable usb, enable chronyd

## FreeIPA

- [ ] Build new node to replace existing FreeIPA node.
- [ ] Create second node in the cloud server as well.

## Synology

- [ ] Re-organize NAS architecture and remove redundant/extraneous folders.
- [ ] Integrate with BackBlaze2 backups.
- [ ] Integrate with Kerberos/FreeIPA correctly
- [ ] Create end-state of:

```bash
/volume1/
	backups/
		proxmox/
		kubernetes/
		workstations/
	shared/
		documents/
		scratch/
	media/
	apps/
		immich/
		nextcloud/
		paperless-ngx/
	iscsi/
		data-lakehouse/
		other-s3-down-the-line/
```

## Kubernetes

- [ ] Convert Kubernetes manifest files to be in production/staging. Staging pointing at local Proxmox server, production pointing at cloud server.

## Docker

- [ ] Create inventory of all sql databases (postgres & sqlite)

```bash
docker compose ps
docker volume ls
docker compose config --volumes
find /opt/appdata -type f \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \)
```

- [ ] Ensure transactions are complete (sqlite WAL)

```bash
docker compose stop
```

- [ ] Bind and snapshot mounts

```bash
mkdir -p ~/migrate
sudo tar czf ~/migrate/appdata-$(date +%F).tar.gz -C /opt/appdata .
```

- [ ] Bind and snapshot named volumes

```bash
mkdir -p ~/migrate/volumes
for v in $(docker volume ls -q); do
  docker run --rm -v "$v":/data:ro -v ~/migrate/volumes:/backup alpine \
    tar czf "/backup/${v}.tar.gz" -C /data .
done
```

- [ ] Pull clean SQLite copies

```bash
mkdir -p ~/migrate/sqlite/{sonarr,radarr,prowlarr,seerr,tautulli}
cp -a /opt/appdata/sonarr/sonarr.db     ~/migrate/sqlite/sonarr/
cp -a /opt/appdata/radarr/radarr.db     ~/migrate/sqlite/radarr/
cp -a /opt/appdata/prowlarr/prowlarr.db ~/migrate/sqlite/prowlarr/
cp -a /opt/appdata/tautulli/tautulli.db ~/migrate/sqlite/tautulli/
```

- [ ] Collect named volumes for each app

```bash
docker run --rm -v sonarr_config:/config:ro -v ~/migrate/sqlite/sonarr:/backup alpine \
  sh -c 'cp -a /config/sonarr.db /backup/'
```

- [ ] Integrity check

```bash
for f in ~/migrate/sqlite/*/*.db; do
  echo "$f"
  sqlite3 "$f" "PRAGMA integrity_check;"
done
```

- [ ] Convert `Overseerr` to `Seerr`

```bash
mkdir -p ~/migrate/seerr
cp -a /opt/appdata/overseerr/db/db.sqlite3 ~/migrate/seerr/
cp -a /opt/appdata/overseerr/settings.json ~/migrate/seerr/
```

- [ ] PostgreSQL dumps

```bash
mkdir -p ~/migrate/postgres
docker exec -t authentik-postgresql-1 \
  pg_dump -U authentik -Fc authentik > ~/migrate/postgres/authentik.dump
```

- [ ] Dump anything else Postgres

```bash
docker exec -t <pg_container> pg_dumpall -U postgres > ~/migrate/postgres/<instance>-all.sql
```

`
