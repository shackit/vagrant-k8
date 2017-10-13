#!/bin/bash

declare -A workers=( ["worker-01"]="192.168.1.81" ["worker-02"]="192.168.1.82")

for instance in worker-01 worker-02; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "UK",
      "L": "England",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "London"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${workers[${instance}]} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done
# Generate certs based on hostname and internal IP
