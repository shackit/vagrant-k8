#!/bin/bash

source /vagrant/common.sh

update_host $2

sudo yum -y install flannel kubernetes

# Configure the kubelet:
echo KUBELET_ADDRESS="--address=0.0.0.0" | sudo tee /etc/kubernetes/kubelet
echo KUBELET_PORT="--port=10250" | sudo tee -a /etc/kubernetes/kubelet
echo KUBELET_HOSTNAME="--hostname_override=${2}" | sudo tee -a /etc/kubernetes/kubelet
echo KUBELET_API_SERVER="--api_servers=http://${MASTER_IP}:8080" | sudo tee -a /etc/kubernetes/kubelet
echo KUBELET_ARGS="--cluster-dns=172.16.0.10" | sudo tee -a /etc/kubernetes/kubelet

# Point flannel to Master IP:
sudo sed -i "s/FLANNEL_ETCD_ENDPOINTS=\"http:\/\/127.0.0.1:2379\"/FLANNEL_ETCD_ENDPOINTS=\"http:\/\/${MASTER_IP}:2379\"/g" /etc/sysconfig/flanneld

# Point kubernetes to Master IP:
sudo sed -i "s/KUBE_MASTER=\"--master=http:\/\/127.0.0.1:8080\"/KUBE_MASTER=\"--master=http:\/\/${MASTER_IP}:8080\"/g" /etc/kubernetes/config
iface=$(ip a | grep ${1} | cut -d ' ' -f 11)
sudo sed -i "s/#FLANNEL_OPTIONS=\"\"/FLANNEL_OPTIONS=\"--iface=${iface}\"/g" /etc/sysconfig/flanneld

# Enable and restart all kuberenets related services:
for SVC in kube-proxy kubelet flanneld docker; do
    systemctl restart $SVC
    systemctl enable  $SVC
    systemctl status  $SVC
done
