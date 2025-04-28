#!/bin/bash

kind create cluster --name tc
kind create cluster --name lo

helm upgrade --install \
    --wait \
    --create-namespace \
    --namespace logging \
    logging-operator oci://ghcr.io/kube-logging/helm-charts/logging-operator \
    --set extraArgs='{"-enable-leader-election=true","-enable-telemetry-controller-route"}' \
    --set telemetry-controller.install=true \
    --set testReceiver.enabled=true

kubectl apply -f ./KCD/1-multi-tenancy/tc-tenant-a-logging.yaml \
              -f ./KCD/1-multi-tenancy/tc-tenant-infra-logging.yaml \
              -f ./KCD/1-multi-tenancy/tc-tenant-infra-receiver.yaml

helm upgrade --install --namespace customer-a log-generator oci://ghcr.io/kube-logging/helm-charts/log-generator
helm upgrade --install --namespace infra log-generator oci://ghcr.io/kube-logging/helm-charts/log-generator
