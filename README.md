# redis_exporter development environment

## Build and test redis_exporter

> Run tests within docker-composer
make docker-test

> Enable logging in tests:
> Add in testcase: log.SetLevel(log.DebugLevel)

> Run CI local
drone exec --event=pull_request | tee -a log.txt


## Prepare deployment

### Create TLS certs that expire in 5 minutes

./scripts/gen-test-certs.sh "" 5
ls -la /tmp/tls-data

#### Check expiry date of cert
openssl x509 -enddate -noout -in /tmp/tls-data/exporter-c.crt
#### Check cert
openssl x509 -text -in /tmp/tls-data/exporter-c.crt

### Build redis-tls-updater
See tools/redis-tls-updater/README.md

### Build own redis_exporter
cd redis_exporter
docker build --build-arg GOARCH=amd64 -f docker/Dockerfile -t oliver006/redis_exporter:own .
> Update to use it: manifests/redis-and-exporter-deployment.yaml

## Setup

### Setup K8s
kind create cluster --config manifests/kind-config.yaml
k get nodes

### Setup Prometheus
kubectl create -f manifests/prometheus.yaml
kubectl port-forward -n monitoring service/prometheus-service 8080 &
xdg-open http://localhost:8080/targets
> Open the Graphs tab later, and search for: redis_db_keys

### Upload images
kind load docker-image redis-tls-updater:0.1.0
kind load docker-image oliver006/redis_exporter:own

### Setup redis, exporter and redis-tls-updater
kubectl create -f manifests/redis-and-exporter-deployment.yaml

### Deploy tester pod
kubectl apply -f manifests/curlpod.yaml

### Get IP for redis-xxx pod
kubectl get pods -o wide
PODIP=$(kubectl get pods -l app=redis -o=jsonpath="{.items[*].status.podIP}")
POD=$(kubectl get pods -l app=redis -o=jsonpath="{.items[*].metadata.name}")

### Update redis-exporter server keypair to use correct Common Name / IP
./scripts/gen-test-certs.sh exporter-s 5 $PODIP

### Check pods and logs
k logs $POD redis
k logs $POD redis-exporter
k logs $POD redis-tls-updater

### Add key to redis

#### Connect to redis using redis-cli and TLS
> Set key
kubectl exec -it $POD -c redis -- redis-cli --tls --cert /tls-data/exporter-c.crt --key /tls-data/exporter-c.key --cacert /tls-data/ca.crt SET key value

#### Connect to redis_exported metrics using TLS
> Get number of keys, including curl errors
kubectl exec -it curlpod -- curl -vvv --cert /tls-data/curl.crt --key /tls-data/curl.key --cacert /tls-data/ca.crt https://$PODIP:9121/metrics
> Get number of keys only
kubectl exec -it curlpod -- curl -vvv --cert /tls-data/curl.crt --key /tls-data/curl.key --cacert /tls-data/ca.crt https://$PODIP:9121/metrics | grep 'db_keys{db="db0"}'

### Update Redis keypair
./scripts/gen-test-certs.sh redis 10
k logs $POD redis
k logs $POD redis-exporter

### Update redis-exporter client keypair
./scripts/gen-test-certs.sh exporter-c 10
k logs $POD redis-exporter

### Update redis-exporter server keypair (using correct Common Name)
./scripts/gen-test-certs.sh exporter-s 10 $PODIP
k logs $POD redis-exporter

### Update curl keypair
./scripts/gen-test-certs.sh curl 10


### TCP only

#### Connect to redis (when TLS is NOT enabled!)
kubectl exec -it curlpod -- curl -vvv telnet://$PODIP:6379
INFO

#### Connect to redis_exported metrics (when TLS is NOT enabled!)
kubectl exec -it curlpod -- curl -vvv http://$PODIP:9121/metrics


## Debug by adding a ephemeral container with tcpdump
kubectl alpha debug -i redis-674d85dcc9-kc5rv --image=nicolaka/netshoot --target=redis -- tcpdump -i eth0
kubectl alpha debug -i redis-674d85dcc9-kc5rv --image=nicolaka/netshoot --target=redis -- tcpdump -i eth0 -w - | wireshark -k -i -

## Links
https://downey.io/blog/kubernetes-ephemeral-debug-container-tcpdump/
https://geekflare.com/san-ssl-certificate/
