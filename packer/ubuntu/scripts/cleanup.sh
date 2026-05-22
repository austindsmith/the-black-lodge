#!/bin/sh
set -eux

while [ ! -f /var/lib/cloud/instance/boot-finished ]; do
  echo 'Waiting for cloud-init...'
  sleep 1
done

sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt-get -y autoremove --purge
sudo apt-get -y clean
sudo apt-get -y autoclean
sudo rm -f /etc/ssh/ssh_host_*
sudo truncate -s 0 /etc/machine-id
sudo cloud-init clean
sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg
sudo sync
