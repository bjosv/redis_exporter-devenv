# redis_exporter develop environment

## Prepare

### Create TLS certs

./scripts/gen-test-certs.sh
ls -la /tmp/tls-data


## Setup

### Setup K8s
mkdir /tmp/tls-data
kind create cluster --config manifests/kind-config.yaml

### Setup redis and exporter
kubectl create -f manifests/k8s-redis-and-exporter-deployment.yaml

#### Check pods
kubectl get pods
kubectl describe pod redis-6547f5d866-s48bj

#### Check mounts
touch /tmp/tls-data/somefile
kubectl -c redis exec -it redis-6547f5d866-s48bj -- ls -la /tls-data

#### Check logs
k logs redis-859dfb6b54-lvhrw redis
k logs redis-859dfb6b54-lvhrw redis-exporter


### Deploy tester pod
kubectl apply -f manifests/curlpod.yaml

> Get IP for redis-xxx pod
kubectl get pods -o wide
kubectl exec -it curlpod -- curl 10.244.0.6:9121

> Check log
k logs redis-859dfb6b54-lvhrw redis-exporter


#### Connect to redis_exported metrics using TLS (insecure needed due to CN in redis.crt)
kubectl exec -it curlpod -- curl -vvv --cert /tls-data/redis.crt --key /tls-data/redis.key --cacert /tls-data/ca.crt --insecure https://10.244.0.14:9121/metrics

#### Connect to redis (NO TLS)
kubectl exec -it curlpod -- curl -vvv telnet://10.244.0.6:6379
INFO

#### Connect to redis_exported metrics (NO TLS)
kubectl exec -it curlpod -- curl -vvv http://10.244.0.8:9121/metrics


#### Connect to redis using redis-cli and TLS
kubectl exec -it redis-674d85dcc9-kc5rv -c redis -- redis-cli --tls --cert /tls-data/redis.crt --key /tls-data/redis.key --cacert /tls-data/ca.crt INFO



## Debug by adding a ephemeral container with tcpdump
kubectl alpha debug -i redis-674d85dcc9-kc5rv --image=nicolaka/netshoot --target=redis -- tcpdump -i eth0
kubectl alpha debug -i redis-674d85dcc9-kc5rv --image=nicolaka/netshoot --target=redis -- tcpdump -i eth0 -w - | wireshark -k -i -

## Links
https://downey.io/blog/kubernetes-ephemeral-debug-container-tcpdump/
