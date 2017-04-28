#!/bin/bash

source /vagrant/common.sh

update_host master

sudo yum -y install etcd flannel kubernetes

# Download HELM
cd ~
curl -L \
https://kubernetes-helm.storage.googleapis.com/helm-v2.3.0-linux-amd64.tar.gz -O
tar -xf helm-v2.3.0-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm

# Configure etcd:
echo ETCD_NAME=default | sudo tee /etc/etcd/etcd.conf
echo ETCD_DATA_DIR="/var/lib/etcd/default.etcd" | sudo tee -a /etc/etcd/etcd.conf
echo ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379" | sudo tee -a /etc/etcd/etcd.conf
echo ETCD_ADVERTISE_CLIENT_URLS="http://localhost:2379" | sudo tee -a /etc/etcd/etcd.conf

# Configure kubernetes api server:
echo KUBE_API_ADDRESS="--address=0.0.0.0" | sudo tee /etc/kubernetes/apiserver
echo KUBE_API_PORT="--port=8080" | sudo tee -a /etc/kubernetes/apiserver
echo KUBELET_PORT="--kubelet_port=10250" | sudo tee -a /etc/kubernetes/apiserver
echo KUBE_ETCD_SERVERS="--etcd_servers=http://127.0.0.1:2379" | sudo tee -a /etc/kubernetes/apiserver
echo KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=172.16.0.0/16" | sudo tee -a /etc/kubernetes/apiserver
echo KUBE_ADMISSION_CONTROL="--admission_control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ResourceQuota" | sudo tee -a /etc/kubernetes/apiserver
echo KUBELET_ARGS="--cluster-dns=172.16.0.10" | sudo tee -a /etc/kubernetes/kubelet

# Point flannel to Master IP:
sudo sed -i "s/FLANNEL_ETCD_ENDPOINTS=\"http:\/\/127.0.0.1:2379\"/FLANNEL_ETCD_ENDPOINTS=\"http:\/\/${MASTER_IP}:2379\"/g" /etc/sysconfig/flanneld

# Set public interface for flannel - not vagrant nat iface:
# ToDo: This may fix auto discovry of api server
iface=$(ip a | grep ${MASTER_IP} | cut -d ' ' -f 11)
sudo sed -i "s/#FLANNEL_OPTIONS=\"\"/FLANNEL_OPTIONS=\"--iface=${iface}\"/g" /etc/sysconfig/flanneld

for SVC in etcd kube-apiserver kube-controller-manager kube-scheduler flanneld; do
  systemctl restart $SVC
  systemctl enable $SVC
  systemctl status $SVC
done

# Setup Flannel configuration in etcd:
etcdctl set /atomic.io/network/config < /vagrant/flannel-config-vxlan.json
