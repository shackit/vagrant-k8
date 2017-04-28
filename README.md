# vagrant-k8

Run a kubernetes setup locally with Vagrant.

### DNS

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
