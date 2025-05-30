#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kubectl apply -f "${SCRIPT_DIR}/tc-tenant-a-logging.yaml"
kubectl delete -f "${SCRIPT_DIR}/fluentbitagent-infra.yaml"
