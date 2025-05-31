#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kubectl config use-context kind-lo

kubectl apply -f "${SCRIPT_DIR}/tc-tenant-b-logging.yaml" \
                -f "${SCRIPT_DIR}/tc-tenant-infra-logging.yaml" \

kubectl delete pod -n infra infra-fluentd-0

helm upgrade --install --namespace customer-b log-generator oci://ghcr.io/kube-logging/helm-charts/log-generator

cat << 'EOF'

Get the password for the Grafana instances:
    kubectl get secret --namespace customer-b grafana-customer-b -o jsonpath="{.data.admin-password}" | base64 --decode

Port-forward to the Grafana instances to access the UI:
    kubectl port-forward --namespace customer-b service/grafana-customer-b 3002:80
EOF
