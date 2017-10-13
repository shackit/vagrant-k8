#!/bin/bash

source /vagrant/common.sh

update_host $2

config_hosts_file

# The socat binary enables support for the kubectl port-forward command.
sudo apt-get -y install socat

# Download the worker binaries
curl -L -O \
https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz

curl -L -O \
https://github.com/kubernetes-incubator/cri-containerd/releases/download/v1.0.0-alpha.0/cri-containerd-1.0.0-alpha.0.tar.gz

curl -L -O \
https://storage.googleapis.com/kubernetes-release/release/v1.8.0/bin/linux/amd64/kubectl

curl -L -O \
https://storage.googleapis.com/kubernetes-release/release/v1.8.0/bin/linux/amd64/kube-proxy

curl -L -O \
https://storage.googleapis.com/kubernetes-release/release/v1.8.0/bin/linux/amd64/kubelet

# Create installation directories
sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

# Install the worker binaries
sudo tar -xvf cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/
sudo tar -xvf cri-containerd-1.0.0-alpha.0.tar.gz -C /
chmod +x kubectl kube-proxy kubelet
sudo mv kubectl kube-proxy kubelet /usr/local/bin/

# Configure CNI
case "$2" in
  worker-01)
    POD_CIDR=10.200.1.0/24
    ;;

  worker-02)
    POD_CIDR=10.200.2.0/24
    ;;
esac

# create the bridge network configuration
cat > 10-bridge.conf <<EOF
{
  "cniVersion": "0.3.1",
  "name": "bridge",
  "type": "bridge",
  "bridge": "cnio0",
  "isGateway": true,
  "ipMasq": true,
  "ipam": {
    "type": "host-local",
    "ranges": [
      [{"subnet": "${POD_CIDR}"}]
    ],
    "routes": [{"dst": "0.0.0.0/0"}]
  }
}
EOF

# create the looback network configuration
cat > 99-loopback.conf <<EOF
{
  "cniVersion": "0.3.1",
  "type": "loopback"
}
EOF

# Move network configuration into the CNI configuration directory
sudo mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/

# Copy self signed TLS certs into place
sudo cp \
/vagrant/config/${2}-key.pem \
/vagrant/config/${2}.pem /var/lib/kubelet/

sudo cp /vagrant/config/${2}.kubeconfig /var/lib/kubelet/kubeconfig
sudo cp /vagrant/config/ca.pem /var/lib/kubernetes/

# Create the kubelet.service systemd unit file
cat > kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=cri-containerd.service
Requires=cri-containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --fail-swap-on=false \\
  --allow-privileged=true \\
  --anonymous-auth=false \\
  --authorization-mode=Webhook \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --cluster-dns=10.32.0.10 \\
  --cluster-domain=cluster.local \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/cri-containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --pod-cidr=${POD_CIDR} \\
  --register-node=true \\
  --require-kubeconfig \\
  --runtime-request-timeout=15m \\
  --tls-cert-file=/var/lib/kubelet/${2}.pem \\
  --tls-private-key-file=/var/lib/kubelet/${2}-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Configure kubernetes proxy service
sudo cp /vagrant/config/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

# Create the kube-proxy.service systemd unit file
cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --cluster-cidr=10.200.0.0/16 \\
  --kubeconfig=/var/lib/kube-proxy/kubeconfig \\
  --proxy-mode=iptables \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Start the worker services
sudo mv kubelet.service kube-proxy.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable containerd cri-containerd kubelet kube-proxy
sudo systemctl start containerd cri-containerd kubelet kube-proxy
