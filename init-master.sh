#!/bin/bash

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

    [Install]
    WantedBy=multi-user.target
EOF
  sudo mv etcd.service /etc/systemd/system/
}

function install_etcd(){
  # download the etcd release
  curl -L -O \
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
    sudo cp \
    /vagrant/config/ca.pem \
    /vagrant/config/kubernetes-key.pem \
    /vagrant/config/kubernetes.pem /etc/etcd/

    # drop systemd unit file into position
    write_etcd_systemd

    # enable and start etcd service
    sudo systemctl daemon-reload
    sudo systemctl enable etcd
    sudo systemctl start etcd
}

function setup_enc_key(){
    ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
    cat > encryption-config.yaml <<EOF
    kind: EncryptionConfig
    apiVersion: v1
    resources:
      - resources:
          - secrets
        providers:
          - aescbc:
              keys:
                - name: key1
                  secret: ${ENCRYPTION_KEY}
          - identity: {}
EOF
  sudo mv encryption-config.yaml /var/lib/kubernetes/
  sudo chown root:root /var/lib/kubernetes/encryption-config.yaml
}

function write_api_server_systemd(){
    cat > kube-apiserver.service <<EOF
    [Unit]
    Description=Kubernetes API Server
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes

    [Service]
    ExecStart=/usr/local/bin/kube-apiserver \\
      --admission-control=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
      --advertise-address=${INTERNAL_IP} \\
      --allow-privileged=true \\
      --apiserver-count=3 \\
      --audit-log-maxage=30 \\
      --audit-log-maxbackup=3 \\
      --audit-log-maxsize=100 \\
      --audit-log-path=/var/log/audit.log \\
      --authorization-mode=Node,RBAC \\
      --bind-address=0.0.0.0 \\
      --client-ca-file=/var/lib/kubernetes/ca.pem \\
      --enable-swagger-ui=true \\
      --etcd-cafile=/var/lib/kubernetes/ca.pem \\
      --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
      --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
      --etcd-servers=https://${INTERNAL_IP}:2379 \\
      --event-ttl=1h \\
      --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
      --insecure-bind-address=127.0.0.1 \\
      --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
      --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
      --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
      --kubelet-https=true \\
      --runtime-config=api/all \\
      --service-account-key-file=/var/lib/kubernetes/ca-key.pem \\
      --service-cluster-ip-range=10.32.0.0/24 \\
      --service-node-port-range=30000-32767 \\
      --tls-ca-file=/var/lib/kubernetes/ca.pem \\
      --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
      --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
      --v=2
    Restart=on-failure
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
EOF
  sudo mv kube-apiserver.service /etc/systemd/system/
}

function write_controller_manager_systemd(){
    cat > kube-controller-manager.service <<EOF
    [Unit]
    Description=Kubernetes Controller Manager
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes

    [Service]
    ExecStart=/usr/local/bin/kube-controller-manager \\
      --address=0.0.0.0 \\
      --cluster-cidr=10.200.0.0/16 \\
      --cluster-name=kubernetes \\
      --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
      --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
      --leader-elect=true \\
      --master=http://127.0.0.1:8080 \\
      --root-ca-file=/var/lib/kubernetes/ca.pem \\
      --service-account-private-key-file=/var/lib/kubernetes/ca-key.pem \\
      --service-cluster-ip-range=10.32.0.0/24 \\
      --v=2
    Restart=on-failure
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
EOF
  sudo mv kube-controller-manager.service /etc/systemd/system/
}

function write_scheduler_systemd(){
  cat > kube-scheduler.service <<EOF
  [Unit]
  Description=Kubernetes Scheduler
  Documentation=https://github.com/GoogleCloudPlatform/kubernetes

  [Service]
  ExecStart=/usr/local/bin/kube-scheduler \\
    --leader-elect=true \\
    --master=http://127.0.0.1:8080 \\
    --v=2
  Restart=on-failure
  RestartSec=5

  [Install]
  WantedBy=multi-user.target
EOF
  sudo mv kube-scheduler.service /etc/systemd/system/
}

function download_k8_control_plane(){
    if [ -f /usr/local/bin/kube-apiserver ]
    then
        return
    fi

    root_url="https://storage.googleapis.com/kubernetes-release/release"

    curl -L -O "${root_url}/v1.8.0/bin/linux/amd64/kube-apiserver"
    curl -L -O "${root_url}/v1.8.0/bin/linux/amd64/kube-controller-manager"
    curl -L -O "${root_url}/v1.8.0/bin/linux/amd64/kube-scheduler"
    curl -L -O "${root_url}/v1.8.0/bin/linux/amd64/kubectl"

    chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl

    sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl \
    /usr/local/bin/
}

function install_k8_control_plane(){
  download_k8_control_plane
  sudo mkdir -p /var/lib/kubernetes/

  sudo cp \
  /vagrant/config/ca.pem \
  /vagrant/config/ca-key.pem \
  /vagrant/config/kubernetes-key.pem \
  /vagrant/config/kubernetes.pem  /var/lib/kubernetes/

  setup_enc_key
}

function config_k8_control_plane(){
  write_api_server_systemd

  write_controller_manager_systemd

  write_scheduler_systemd
}

INTERNAL_IP=$1

source /vagrant/common.sh

update_host master

config_hosts_file

ETCD_NAME=$(hostname -s)

install_etcd

config_etcd

install_k8_control_plane

config_k8_control_plane

sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler

sleep 30

# Create the system:kube-apiserver-to-kubelet ClusterRole with permissions
# to access the Kubelet API and perform most common tasks associated
# with managing pods
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

# Bind the system:kube-apiserver-to-kubelet ClusterRole to the kubernetes user:
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
