#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kubectl config use-context kind-tc

helm upgrade --install --wait --create-namespace --namespace telemetry-controller-system telemetry-controller oci://ghcr.io/kube-logging/helm-charts/telemetry-controller

kubectl apply -f "${SCRIPT_DIR}/receiver.yaml" \
                -f "${SCRIPT_DIR}/one_tenant_two_subscriptions.yaml"

helm install --wait --create-namespace --namespace example-tenant-ns --generate-name oci://ghcr.io/kube-logging/helm-charts/log-generator
