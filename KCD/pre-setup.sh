#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kind create cluster --name tc
kind create cluster --name lo

helm upgrade --install \
    --wait \
    --create-namespace \
    --namespace logging \
    logging-operator oci://ghcr.io/kube-logging/helm-charts/logging-operator \
    --set extraArgs='{"-enable-leader-election=true","-enable-telemetry-controller-route"}' \
    --set telemetry-controller.install=true

kubectl apply -f "${SCRIPT_DIR}/1-multi-tenancy/tc-tenant-a-logging.yaml" \
              -f "${SCRIPT_DIR}/1-multi-tenancy/tc-tenant-infra-logging.yaml"

helm upgrade --install --namespace customer-a loki-customer-a grafana/loki -f "${SCRIPT_DIR}/1-multi-tenancy/loki-values.yaml"
helm upgrade --install --namespace customer-b loki-customer-b grafana/loki -f "${SCRIPT_DIR}/1-multi-tenancy/loki-values.yaml"
helm upgrade --install --namespace infra loki-infra grafana/loki -f "${SCRIPT_DIR}/1-multi-tenancy/loki-values.yaml"

helm upgrade --install --namespace customer-a grafana-customer-a grafana/grafana \
 --set "datasources.datasources\\.yaml.apiVersion=1" \
 --set "datasources.datasources\\.yaml.datasources[0].name=Loki" \
 --set "datasources.datasources\\.yaml.datasources[0].type=loki" \
 --set "datasources.datasources\\.yaml.datasources[0].url=http://loki-customer-a-gateway.customer-a.svc.cluster.local/" \
 --set "datasources.datasources\\.yaml.datasources[0].access=proxy"

helm upgrade --install --namespace customer-b grafana-customer-b grafana/grafana \
 --set "datasources.datasources\\.yaml.apiVersion=1" \
 --set "datasources.datasources\\.yaml.datasources[0].name=Loki" \
 --set "datasources.datasources\\.yaml.datasources[0].type=loki" \
 --set "datasources.datasources\\.yaml.datasources[0].url=http://loki-customer-b-gateway.customer-b.svc.cluster.local/" \
 --set "datasources.datasources\\.yaml.datasources[0].access=proxy"

helm upgrade --install --namespace infra grafana-infra grafana/grafana \
 --set "datasources.datasources\\.yaml.apiVersion=1" \
 --set "datasources.datasources\\.yaml.datasources[0].name=Loki" \
 --set "datasources.datasources\\.yaml.datasources[0].type=loki" \
 --set "datasources.datasources\\.yaml.datasources[0].url=http://loki-infra-gateway.infra.svc.cluster.local/" \
 --set "datasources.datasources\\.yaml.datasources[0].access=proxy"

helm upgrade --install --namespace customer-a log-generator oci://ghcr.io/kube-logging/helm-charts/log-generator
helm upgrade --install --namespace infra log-generator oci://ghcr.io/kube-logging/helm-charts/log-generator

cat << 'EOF'

Get the password for the Grafana instances:
    kubectl get secret --namespace customer-a grafana-customer-a -o jsonpath="{.data.admin-password}" | base64 --decode
    kubectl get secret --namespace infra grafana-infra -o jsonpath="{.data.admin-password}" | base64 --decode

Port-forward to the Grafana instances to access the UI:
    kubectl port-forward --namespace customer-a service/grafana-customer-a 3000:80
    kubectl port-forward --namespace infra service/grafana-infra 3001:80
EOF
