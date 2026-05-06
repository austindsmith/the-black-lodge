#!/bin/sh
set -eux

while [ ! -f /var/lib/cloud/instance/boot-finished ]; do
  echo 'Waiting for cloud-init...'
  sleep 1
done

sudo rm -f /etc/ssh/ssh_host_*
sudo truncate -s 0 /etc/machine-id
sudo dnf clean all
sudo cloud-init clean
sudo sync