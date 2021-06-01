# redis_exporter develop environment

## Setup

kind create cluster
kubectl create -f manifests/k8s-redis-and-exporter-deployment.yaml
kubectl -n redis get pods
