#!/bin/bash

source /vagrant/common.sh

update_host master

config_hosts_file

INTERNAL_IP=$1

ETCD_NAME=$(hostname -s)

function write_etcd_systemd(){
    cat > etcd.service <<EOF
    [Unit]
    Description=etcd
    Documentation=https://github.com/coreos

    [Service]
    ExecStart=/usr/local/bin/etcd \\
      --name ${ETCD_NAME} \\
      --cert-file=/etc/etcd/kubernetes.pem \\
      --key-file=/etc/etcd/kubernetes-key.pem \\
      --peer-cert-file=/etc/etcd/kubernetes.pem \\
      --peer-key-file=/etc/etcd/kubernetes-key.pem \\
      --trusted-ca-file=/etc/etcd/ca.pem \\
      --peer-trusted-ca-file=/etc/etcd/ca.pem \\
      --peer-client-cert-auth \\
      --client-cert-auth \\
      --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
      --listen-peer-urls https://${INTERNAL_IP}:2380 \\
      --listen-client-urls https://${INTERNAL_IP}:2379,http://127.0.0.1:2379 \\
      --advertise-client-urls https://${INTERNAL_IP}:2379 \\
      --initial-cluster-token etcd-cluster-0 \\
      --initial-cluster master=https://${INTERNAL_IP}:2380 \\
      --initial-cluster-state new \\
      --data-dir=/var/lib/etcd
    Restart=on-failure
    RestartSec=5

    #[Install]
    WantedBy=multi-user.target
EOF
    sudo mv etcd.service /etc/systemd/system/
}

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

    # drop systemd unit file into position
    write_etcd_systemd

    # enable and start etcd service
    sudo systemctl daemon-reload
    sudo systemctl enable etcd
    sudo systemctl start etcd
}

install_etcd

config_etcd
