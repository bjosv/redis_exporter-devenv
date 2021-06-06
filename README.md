# redis_exporter develop environment

## Prepare

### Create TLS certs

./scripts/gen-test-certs.sh
ls -la /tmp/tls-data

#### Check expiry date of cert
openssl x509 -enddate -noout -in /tmp/tls-data/redis.crt

## Setup

### Setup K8s
kind create cluster --config manifests/kind-config.yaml
k get nodes

### Setup redis and exporter
kubectl create -f manifests/k8s-redis-and-exporter-deployment.yaml

#### Check pods
kubectl get pods -o wide
kubectl describe pod redis-6547f5d866-s48bj

#### Check logs
k logs redis-859dfb6b54-lvhrw redis
k logs redis-859dfb6b54-lvhrw redis-exporter


### Deploy tester pod
kubectl apply -f manifests/curlpod.yaml

> Get IP for redis-xxx pod
kubectl get pods -o wide


#### Connect to redis_exported metrics using TLS (insecure needed due to CN in redis.crt dont points to IP)
kubectl exec -it curlpod -- curl -vvv --cert /tls-data/redis.crt --key /tls-data/redis.key --cacert /tls-data/ca.crt --insecure https://10.244.0.5:9121/metrics

#### Connect to redis using redis-cli and TLS
kubectl exec -it redis-674d85dcc9-kc5rv -c redis -- redis-cli --tls --cert /tls-data/redis.crt --key /tls-data/redis.key --cacert /tls-data/ca.crt INFO

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
