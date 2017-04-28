When I try to `helm init` tiller keeps crash looping with this error message:

>Cannot initialize Kubernetes connection: Get http://localhost:8080/api: dial tcp 127.0.0.1:8080: getsockopt: connection refused`.

Trying to track down where localhost is being set I came to
https://github.com/kubernetes/kubernetes/blob/8fd414537b5143ab039cb910590237cabf4af783/staging/src/k8s.io/client-go/1.4/tools/clientcmd/client_config.go#L39

```...
DefaultCluster = clientcmdapi.Cluster{Server: "http://localhost:8080"}

// EnvVarCluster allows overriding the DefaultCluster using an envvar for the server name
EnvVarCluster = clientcmdapi.Cluster{Server: os.Getenv("KUBERNETES_MASTER")}
...```

If I run `helm init --debug` and add the following to the spec, I can successfully deploy tiller manually.

```- name: KUBERNETES_MASTER
 value: http://192.168.1.80:8080```

I am pretty sure this is a configuration issue with my setup, but I was hoping someone could how to configure  such that I can use
`helm init` without having to resort to the above workaround?

Thanks
