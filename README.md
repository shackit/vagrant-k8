# vagrant-k8

> A vagrant implementation of Kubernetes the Hard way

https://github.com/kelseyhightower/kubernetes-the-hard-way

### Testing

```
curl --cacert ca.pem https://192.168.1.80:6443/version
```

#### Configure vagrant host to talk to the cluster

```
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=./config/ca.pem \
  --embed-certs=true \
  --server=https://192.168.1.80:6443

kubectl config set-credentials admin \
  --client-certificate=./config/admin.pem \
  --client-key=./config/admin-key.pem

kubectl config set-context kubernetes-the-hard-way \
  --cluster=kubernetes-the-hard-way \
  --user=admin

kubectl config use-context kubernetes-the-hard-way
```

### DNS

* references: https://github.com/kubernetes/kubernetes/issues/21613

#### Run a network tools container on the cluster to test DNS

```
# launch a pod
$ kubectl run tools --image=ianneub/network-tools --command -- sleep 3600

# get launched pods name
$ POD_NAME=$(kubectl get pods -l run=tools -o jsonpath="{.items[0].metadata.name}")

# output the content of resolv.conf
kubectl exec -ti $POD_NAME -- cat /etc/resolv.conf
search default.svc.cluster.local svc.cluster.local cluster.local home
nameserver 10.32.0.10
options ndots:5

# run an nslookup command
kubectl exec -ti $POD_NAME -- nslookup kubernetes
;; reply from unexpected source: 10.200.1.5#53, expected 10.32.0.10#53
;; reply from unexpected source: 10.200.1.5#53, expected 10.32.0.10#53
;; reply from unexpected source: 10.200.1.5#53, expected 10.32.0.10#53
;; connection timed out; no servers could be reached
```

#### Observe DNS traffic

```
sudo tcpdump -i cnio0 -vvv -s 0 -l -n port 53 | grep kubernetes
```

#### Adding this POSTROUTING iptables rule to the worker resolves DNS resolution
```
$ sudo iptables -t nat -I POSTROUTING -s 10.200.1.0/24 -d 10.200.1.0/24 -j MASQUERADE

$ kubectl exec -ti $POD_NAME -- nslookup kubernetes
Server:		10.32.0.10
Address:	10.32.0.10#53

Non-authoritative answer:
Name:	kubernetes.default.svc.cluster.local
Address: 10.32.0.1
```

### Setup the kube-system namespace

> 31/03/2017: This namespace exists without having to create.

    kubectl create namespace kube-system

### Replication Controller

    kubectl create -f /vagrant/pods/dns/kube-dns-rc.yaml

Confirm that the replication controller is present:

    kubectl get rc --namespace kube-system
    NAME           DESIRED   CURRENT   READY     AGE
    kube-dns-v18   1         1         1         8m

### Service

    kubectl create -f /vagrant/pods/dns/kube-dns-svc.yaml

Confirm that the DNS service is present:

    kubectl get svc --namespace kube-system
    NAME       CLUSTER-IP    EXTERNAL-IP   PORT(S)         AGE
    kube-dns   172.16.0.10   <none>        53/UDP,53/TCP   1m


## Dashboard

The kube-system namespace and DNS are pre-requisites.

### Deployment

    kubectl create -f /vagrant/pods/dashboard/deployment.yaml

Confirm the Dashboard deployment is present:

    kubectl get deployment --namespace kube-system
    NAME                   DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
    kubernetes-dashboard   1         1         1            1           16s

### Service

    kubectl create -f /vagrant/pods/dashboard/service.yaml

Confirm that the Dashboard service is present:

    kubectl get svc --namespace kube-system
    NAME                   CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
    kubernetes-dashboard   172.17.227.182   <nodes>       80:30975/TCP   5m

## HELM

    helm install stable/mysql

The storage class of alpha or default is not working for some reason. So simply
remove this annotation from the pod allows the pod to enter Running state.

    kubectl annotate pvc nobby-mouse-mysql volume.alpha.kubernetes.io/storage-class-

## Basic example running nginx

    kubectl run nginx --image=nginx --replicas=2 --port=80

This didn't work locally on vagrant

    kubectl expose deployment nginx --port=80

Explicitly expose a deployment on a particular IP

    kubectl expose deployment nginx --port=80 --external-ip=192.168.1.81


## Basic example running a custom container

Create a custom namespace

    kubectl create -f /vagrant/pods/node-demo/namespace.yaml

Create the pod

    kubectl create -f /vagrant/pods/node-demo/pod.yaml

Create the service

    kubectl create -f /vagrant/pods/node-demo/service.yaml
