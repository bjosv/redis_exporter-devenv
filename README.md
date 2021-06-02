# redis_exporter develop environment

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
