#!/bin/bash

function create_ca_config() {
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
}

function create_ca_csr() {
cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "UK",
      "L": "England",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "London"
    }
  ]
}
EOF
}

create_ca_config

create_ca_csr

cfssl gencert -initca ca-csr.json | cfssljson -bare ca
