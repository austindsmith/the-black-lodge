#!/bin/sh
set -eux

echo "Waiting for cloud-init..."
cloud-init status --wait

sudo rm -f /etc/ssh/ssh_host_*
sudo truncate -s 0 /etc/machine-id
sudo dnf clean all
sudo cloud-init clean
sudo sync
