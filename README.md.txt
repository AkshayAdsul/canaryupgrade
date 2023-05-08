#Repo
https://github.com/AkshayAdsul/canaryupgrade.git

# Reference: https://docs.solo.io/gloo-edge/latest/operations/production_deployment/#downstream-to-envoy-health-checks

# Enable Downstream to Envoy HealthChecks
```
gloo:
  gatewayProxies:
    gatewayProxy:
      kind:
        deployment:
          restartPolicy: Always
      podTemplate:
        probes: true
        # added below
        livenessProbeEnabled: true
        customReadinessProbe:
          httpGet:
            scheme: HTTP
            port: 8080
            path: /health/ready
          failureThreshold: 2
          initialDelaySeconds: 5
          periodSeconds: 5
```

# Reference: https://docs.solo.io/gloo-edge/latest/guides/traffic_management/request_processing/health_checks/
# gateway HealthCheck
gloo:
  gatewayProxies:
    gatewayProxy:
      gatewaySettings:
        customHttpGateway: `added`
          options: `added`
            healthCheck: `added`
              path: /health/ready `added`
            httpConnectionManagerSettings:
              useRemoteAddress: true

# Reference : https://docs.solo.io/gloo-edge/master/guides/integrations/google_cloud/#configuration-in-gcp-for-nlb
# Reference: https://cloud.google.com/kubernetes-engine/docs/how-to/internal-load-balancing
# Set gateway-proxy loadBalancerIP to StaticIP ()
gloo:
  gatewayProxies:
    gatewayProxy:
      service:
        type: LoadBalancer
        loadBalancerIP: 10.152.0.10
        extraAnnotations:
          networking.gke.io/load-balancer-type: "Internal"
          prometheus.io/path: /metrics
          prometheus.io/port: "8081"
          prometheus.io/scrape: "true"


# install GE 1-11-43
helm install gloo glooe/gloo-ee --namespace gloo-system --version 1.11.43 -f helmvalues-edgetest-staticLBIP-1-11-43.yaml --create-namespace --set-string license_key=$GLOO_EDGE_LICENSE_KEY

# deploy test workload and virtual service
kubectl apply -f echoenv.yaml
kubectl apply -f echoenv-vs-1-11-43.yaml

# In Locust, set the host `http://load.gojektesting.apac.fe.gl00.net` > DNS record is created in GCP

# access Locust localhost:8089
kubectl port-forward svc/locust --address 0.0.0.0 8089:8089 --context gke_field-engineering-apac_australia-southeast1_ash-locust-client

###########################################
  CANARY UPGRADE from 1-11-43 to 1-14-1
###########################################

# Upgrade your version of glooctl
# Reference https://docs.solo.io/gloo-edge/latest/operations/upgrading/upgrade_steps/#step-2-upgrade-glooctl
glooctl upgrade --release v1.14.1


# Get the new CRDs version 1-14-1
helm repo update

mkdir 1-14-1 && cd 1-14-1
helm pull glooe/gloo-ee --version 1.14.1 --untar


# Note: Compare version in the Changelog https://docs.solo.io/gloo-edge/latest/reference/changelog/enterprise/#compareversions_v1.11.43...v1.14.1`

# Note: compare 1-11-43/gloo-ee/values.yaml `vs` 1-14-1/gloo-ee/values.yaml` to check anything we need to update.


# Apply the new and updated CRDs for the newer version (e.g:) 1.14.1
cd ..
kubectl apply -f 1-14-1/gloo-ee/charts/gloo/crds

# If Gloo Federation is enabled
kubectl apply -f 1-14-1/gloo-ee/charts/gloo-fed/crds


# check the Locust for any failures and also gateway-proxy HPA

# just for canary upgrade add the following the helm values for 1-14-1 in helmvalues-edgetest-staticLBIP-1-14-1.yaml
# to add
global:
  glooRbac:
    nameSuffix: 1-14-1

gloo:
  settings:
    watchNamespaces:
      - gloo-system-1-14-1
      - default

# Update gateway-proxy loadBalancerIP
gloo:
  gatewayProxies:
    gatewayProxy:
      service:
        type: LoadBalancer
        loadBalancerIP: 10.152.0.11 `make sure this ip in mapped to DNS A record in GCP`
        extraAnnotations:
          networking.gke.io/load-balancer-type: "Internal"
          prometheus.io/path: /metrics
          prometheus.io/port: "8081"
          prometheus.io/scrape: "true"

# add virtualServiceNamespaces:
gloo:
  gatewayProxies:
    gatewayProxy:
      gatewaySettings:
        customHttpGateway:
          virtualServiceNamespaces: `added`
            - gloo-system-1-14-1 `added`
          options:
            healthCheck:
              path: /health/ready
            httpConnectionManagerSettings:
              useRemoteAddress: true

#########################
install GlooEdge 1-14-1
#########################

`Create a new namespace to install newer version of GE`
kubectl create ns gloo-system-1-14-1

helm install gloo-1-14-1 glooe/gloo-ee --namespace gloo-system-1-14-1 --version 1.14.1 -f helmvalues-edgetest-staticLBIP-1-14-1.yaml --create-namespace --set-string license_key=$GLOO_EDGE_LICENSE_KEY

`Create VS for 1-14-1`
kubectl create -f echoenv-vs-1-14-1.yaml


`helm list -A`
NAME       	NAMESPACE         	REVISION	UPDATED                              	STATUS  	CHART          	APP VERSION
gloo       	gloo-system       	1       	2023-05-03 10:16:13.901 +1000 AEST   	deployed	gloo-ee-1.11.43	           
gloo-1-14-1	gloo-system-1-14-1	2       	2023-05-03 12:07:07.276895 +1000 AEST	deployed	gloo-ee-1.14.1 

`kubectl get svc -A | grep gateway-proxy`
gloo-system-1-14-1   gateway-proxy                         LoadBalancer   10.116.71.116   10.152.0.11   80:30424/TCP,443:31041/TCP                             4d23h
gloo-system          gateway-proxy                         LoadBalancer   10.116.70.35    10.152.0.10   80:31829/TCP,443:31898/TCP                             5d


`kubectl get upstreams -A | grep echo`
gloo-system-1-14-1   default-echoenv-service-1-8080                         8m21s
gloo-system           default-echoenv-service-1-8080                         117m


`kubectl get hpa -A`

# verify hpa is set to 5
$ kubectl get hpa -A
NAMESPACE             NAME                REFERENCE                  TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
gloo-system-1-14-1   gateway-proxy-hpa   Deployment/gateway-proxy   0%/70%    1         16        1          37m
gloo-system           gateway-proxy-hpa   Deployment/gateway-proxy   83%/70%   1         16        5          147m
