# Gloo Edge scale tests on GKE
Repo for scale tests of Gloo Edge

## Setup Gloo Edge Enterprise

### Create a GKE cluster
`./create-gke-cluster.sh`

This will create a GKE cluster with machine type `n2-highcpu-16`.

### Install Gloo Edge Enterprise
`helm install gloo glooe/gloo-ee --namespace gloo-system -f helmvalues-edgetest.yaml --create-namespace --set-string license_key=$GLOO_EDGE_LICENSE_KEY`

This will install gloo edge enterprise version on GKE cluster

## Setup Load Test Client
For this setup we will use locust client. Lets create a GKE cluster for locust.

`./create-locust-cluster.sh`

### Install locust on this cluster
Check and ensure that main.py for locust is set up properly

```
kubectl create configmap my-loadtest-locustfile --from-file ./main.py

helm install locust deliveryhero/locust \
  --set loadtest.name=my-loadtest \
  --set loadtest.locust_locustfile_configmap=my-loadtest-locustfile
```

Now port forward to locust and start the test
```
kubectl --context locust --namespace default port-forward service/locust 8089:8089
```

Head over to `http://localhost:8089` and start the swarm
