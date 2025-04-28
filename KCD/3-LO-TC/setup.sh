#!/bin/bash

kubectl config use-context kind-lo

kubectl apply -f ./KCD/3-LO-TC/tc-tenant-b-logging.yaml \
              -f ./KCD/3-LO-TC/tc-tenant-infra-logging.yaml \

kubectl delete pod -n infra infra-fluentd-0

helm upgrade --install --namespace customer-b log-generator oci://ghcr.io/kube-logging/helm-charts/log-generator
