# vagrant-k8

> A vagrant implementation of Kubernetes the Hard way

https://github.com/kelseyhightower/kubernetes-the-hard-way

### Setup

```
$ vagrant up master
...
$ vagrant up worker-01 worker-02
...

vagrant ssh worker-01
sudo iptables -t nat -I POSTROUTING -s 10.200.1.0/24 -d 10.200.1.0/24 -j MASQUERADE
sudo route add -net 10.200.2.0/24 gw 192.168.1.82 dev enp0s8

vagrant ssh worker-02
sudo iptables -t nat -I POSTROUTING -s 10.200.2.0/24 -d 10.200.2.0/24 -j MASQUERADE
sudo route add -net 10.200.1.0/24 gw 192.168.1.81 dev enp0s8

# create dns service
kubectl create -f ./deployments/kube-dns.yaml

# create a couple of test pods for dns resolution
kubectl create -f ./deployments/tools-01.yaml
kubectl create -f ./deployments/tools-02.yaml

```

#### Configure

Configure the vagrant/virtualbox host to talk to the cluster

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

### Validate

```
$ curl --cacert ca.pem https://192.168.1.80:6443/version

{
  "major": "1",
  "minor": "8",
  "gitVersion": "v1.8.0",
  "gitCommit": "6e937839ac04a38cac63e6a7a306c5d035fe7b0a",
  "gitTreeState": "clean",
  "buildDate": "2017-09-28T22:46:41Z",
  "goVersion": "go1.8.3",
  "compiler": "gc",
  "platform": "linux/amd64"
}

$ kubectl get componentstatus
NAME                 STATUS    MESSAGE              ERROR
etcd-0               Healthy   {"health": "true"}   
scheduler            Healthy   ok                   
controller-manager   Healthy   ok  

$ kubectl get nodes
NAME        STATUS    ROLES     AGE       VERSION
worker-01   Ready     <none>    2m        v1.8.0
```

### Testing

### Issues

* https://github.com/kubernetes/kubernetes/issues/21613
* https://stackoverflow.com/questions/44312745/kubernetes-rbac-unable-to-upgrade-connection-forbidden-user-systemanonymous
> Run a network tools container on the cluster to test DNS

```
# launch a pod
$ kubectl run tools --image=ianneub/network-tools --command -- sleep 3600

# get launched pods name
$ POD_NAME=$(kubectl get pods -l run=tools -o jsonpath="{.items[0].metadata.name}")

# output the content of resolv.conf
$ kubectl exec -ti $POD_NAME -- cat /etc/resolv.conf
search default.svc.cluster.local svc.cluster.local cluster.local home
nameserver 10.32.0.10
options ndots:5

# run an nslookup command
$ kubectl exec -ti $POD_NAME -- nslookup kubernetes
;; reply from unexpected source: 10.200.1.5#53, expected 10.32.0.10#53
;; reply from unexpected source: 10.200.1.5#53, expected 10.32.0.10#53
;; reply from unexpected source: 10.200.1.5#53, expected 10.32.0.10#53
;; connection timed out; no servers could be reached
```

> Observe DNS traffic, from a worker node

```
$ sudo tcpdump -i cnio0 -vvv -s 0 -l -n port 53 | grep kubernetes
tcpdump: listening on cnio0, link-type EN10MB (Ethernet), capture size 262144 bytes
    10.200.1.4.42064 > 10.32.0.10.53: [bad udp cksum 0x1645 -> 0x2f75!] 21404+ A? kubernetes.default.svc.cluster.local. (54)
    10.200.1.4.42064 > 10.200.1.3.53: [bad udp cksum 0x17e6 -> 0x2dd4!] 21404+ A? kubernetes.default.svc.cluster.local. (54)
    10.200.1.3.53 > 10.200.1.4.42064: [bad udp cksum 0x17f6 -> 0xe2ee!] 21404 q: A? kubernetes.default.svc.cluster.local. 1/0/0 kubernetes.default.svc.cluster.local. [16s] A 10.32.0.1 (70)

```

> Adding this POSTROUTING iptables rule to the worker resolves DNS resolution

```
$ sudo iptables -t nat -I POSTROUTING -s 10.200.1.0/24 -d 10.200.1.0/24 -j MASQUERADE

$ kubectl exec -ti $POD_NAME -- nslookup kubernetes
Server:     10.32.0.10
Address:    10.32.0.10#53

Non-authoritative answer:
Name:	kubernetes.default.svc.cluster.local
Address: 10.32.0.1
```

> Observe DNS traffic
```
sudo tcpdump -i cnio0 -vvv -s 0 -l -n port 53 | grep kubernetes
tcpdump: listening on cnio0, link-type EN10MB (Ethernet), capture size 262144 bytes
    10.200.1.4.40513 > 10.32.0.10.53: [bad udp cksum 0x1645 -> 0x6d17!] 7177+ A? kubernetes.default.svc.cluster.local. (54)
    10.200.1.1.40513 > 10.200.1.3.53: [bad udp cksum 0x17e3 -> 0x6b79!] 7177+ A? kubernetes.default.svc.cluster.local. (54)
    10.200.1.3.53 > 10.200.1.1.40513: [bad udp cksum 0x17f3 -> 0x209d!] 7177 q: A? kubernetes.default.svc.cluster.local. 1/0/0 kubernetes.default.svc.cluster.local. [7s] A 10.32.0.1 (70)
    10.32.0.10.53 > 10.200.1.4.40513: [bad udp cksum 0x1655 -> 0x223b!] 7177 q: A? kubernetes.default.svc.cluster.local. 1/0/0 kubernetes.default.svc.cluster.local. [7s] A 10.32.0.1 (70)
```
