#!/bin/bash

export MASTER_IP=192.168.1.80

update_host() {
  sudo yum -y update
  sudo yum -y clean all

  sudo hostnamectl set-hostname $1

  sudo yum -y install ntp

  sudo systemctl stop firewalld
  sudo systemctl disable firewalld

  sudo systemctl start ntpd
  sudo systemctl enable ntpd
}

config_nfs_worker() {
  yum install nfs-utils

  sudo mkdir -p /mnt/nfs
  sudo chown vagrant /mnt/nfs

  echo "192.168.1.50:/var/nfs  /mnt/nfs  nfs  rw,sync,hard,intr  0  0" |
  sudo tee -a /etc/fstab

}
