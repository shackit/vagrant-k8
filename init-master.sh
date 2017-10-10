#!/bin/bash

source /vagrant/common.sh

update_host master

config_hosts_file

function install_etcd(){
    # download the etcd release
    wget -q --show-progress --https-only --timestamping \
    "https://github.com/coreos/etcd/releases/download/v3.2.8/etcd-v3.2.8-linux-amd64.tar.gz"

    # unpack the etcd release
    tar -xvf etcd-v3.2.8-linux-amd64.tar.gz

    # make it accessible system wide
    sudo mv etcd-v3.2.8-linux-amd64/etcd* /usr/local/bin/
}

function config_etcd(){
    # setup config directories
    sudo mkdir -p /etc/etcd /var/lib/etcd

    # copy self signed tls certs into place
    sudo cp /vagrant/thw/certs/01_ca/ca.pem \
    /vargrant/thw/05_kubernetes/kubernetes-key.pem \
    /vargrant/thw/05_kubernetes/kubernetes.pem /etc/etcd/
}
