# redis_exporter develop environment

## Prepare

### Create TLS certs that expire in 4 minutes

./scripts/gen-test-certs.sh "" 4
ls -la /tmp/tls-data

#### Check expiry date of cert
openssl x509 -enddate -noout -in /tmp/tls-data/redis.crt

### Build redis-tls-updater
See tools/redis-tls-updater/README.md

### Build own redis_exporter
cd redis_exporter
docker build -f docker/Dockerfile.amd64 -t oliver006/redis_exporter:own .

## Setup

### Setup K8s
kind create cluster --config manifests/kind-config.yaml
k get nodes

### Upload images
kind load docker-image redis-tls-updater:0.1.0
kind load docker-image oliver006/redis_exporter:own

### Setup redis, exporter and redis-tls-updater
kubectl create -f manifests/k8s-redis-and-exporter-deployment.yaml

### Deploy tester pod
kubectl apply -f manifests/curlpod.yaml

### Check pods and logs
kubectl get pods -o wide
k logs redis-859dfb6b54-lvhrw redis
k logs redis-859dfb6b54-lvhrw redis-exporter

### Get IP for redis-xxx pod
kubectl get pods -o wide
PODIP=$(kubectl get pods -l app=redis -o=jsonpath="{.items[*].status.podIP}")
POD=$(kubectl get pods -l app=redis -o=jsonpath="{.items[*].metadata.name}")

### Update Redis keypair

#### Connect to redis using redis-cli and TLS
> Set key
kubectl exec -it $POD -c redis -- redis-cli --tls --cert /tls-data/redis.crt --key /tls-data/redis.key --cacert /tls-data/ca.crt SET key value

#### Connect to redis_exported metrics using TLS (insecure needed due to CN in redis.crt don't points to IP)
> Get number of keys
kubectl exec -it curlpod -- curl -vvv --cert /tls-data/curl.crt --key /tls-data/curl.key --cacert /tls-data/ca.crt --insecure https://$PODIP:9121/metrics | grep 'db_keys{db="db0"}'


#### Connect to redis (when TLS is NOT enabled!)
kubectl exec -it curlpod -- curl -vvv telnet://10.244.0.5:6379
INFO

#### Connect to redis_exported metrics (when TLS is NOT enabled!)
kubectl exec -it curlpod -- curl -vvv http://10.244.0.5:9121/metrics


## Debug by adding a ephemeral container with tcpdump
kubectl alpha debug -i redis-674d85dcc9-kc5rv --image=nicolaka/netshoot --target=redis -- tcpdump -i eth0
kubectl alpha debug -i redis-674d85dcc9-kc5rv --image=nicolaka/netshoot --target=redis -- tcpdump -i eth0 -w - | wireshark -k -i -

## Links
https://downey.io/blog/kubernetes-ephemeral-debug-container-tcpdump/
