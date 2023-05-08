
#Setup helm
#helm repo add glooe https://storage.googleapis.com/gloo-ee-helm

#Install Gloo Edge
helm install gloo glooe/gloo-ee --namespace gloo-system -f helmvalues-edgetest.yaml --create-namespace --set-string license_key=$GLOO_EDGE_LICENSE_KEY
