#!/bin/bash

# https://www.howtoforge.com/tutorial/setting-up-an-nfs-server-and-client-on-centos-7/

source /vagrant/common.sh

update_host $2

yum -y install nfs-utils

sudo systemctl enable nfs-server.service
sudo systemctl start nfs-server.service

# setup nfs mount point:
sudo mkdir /var/nfs
sudo chown nfsnobody:nfsnobody /var/nfs
sudo chmod 755 /var/nfs

# update nfs export config:
echo "/var/nfs    192.168.1.81(rw,sync,no_root_squash,no_subtree_check)" |
    sudo tee -a /etc/exports

# cement nfs changes:
sudo exportfs -a
