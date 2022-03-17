# Setup with Grafana

## Start K8s cluster
./scripts/gen-test-certs.sh

## Preparing Kubernetes v1.22.2 on Docker 20.10.8 ...
minikube config set memory 8192
minikube config set cpus 6
minikube start --mount-string="/tmp/tls-data:/tls-data" --mount
minikube status

## Install prometheus
kubectl create -f manifests/prometheus.yaml
kubectl port-forward -n monitoring service/prometheus-service 8080 &
xdg-open http://localhost:8080/targets

## Install and setup Grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana -n monitoring

### Get password for 'admin':
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

### Access
export POD_NAME=$(kubectl get pods -n monitoring -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl -n monitoring port-forward $POD_NAME 3000 &
xdg-open http://localhost:3000

### Configure
#### Add data source
Menu: <Cog icon> Configure --> Data sources --> Prometheus
URL: http://prometheus-service:8080
Save and test

#### Add dashboard
https://grafana.com/grafana/dashboards/15398


## Build
docker build --build-arg GOARCH=amd64 -f docker/Dockerfile -t oliver006/redis_exporter:1.16.7 --no-cache .

## Upload containers
minikube image load redis-tls-updater:0.1.0
minikube image load oliver006/redis_exporter:1.16.7
minikube image load oliver006/redis_exporter:1.18-dlv

## Install deployment
kubectl create -f manifests/redis-and-exporter-deployment.yaml

-alt

kubectl create -f manifests/redis-and-exporter-deployment-delve.yaml

# Links
https://opensource.com/article/21/6/chaos-grafana-prometheus
https://www.jetbrains.com/help/go/exploring-go-core-dumps.html
