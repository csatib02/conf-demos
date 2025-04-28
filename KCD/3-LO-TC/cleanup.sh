#!/bin/bash

kubectl apply -f ./KCD/3-LO-TC/tc-tenant-a-logging.yaml
kubectl delete -f ./KCD/3-LO-TC/fluentbitagent-infra.yaml
