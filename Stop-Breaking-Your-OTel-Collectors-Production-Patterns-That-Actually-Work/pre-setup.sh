#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="kcd-czech-slovak-demo"
MANIFESTS="${SCRIPT_DIR}/manifests"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

setup_cluster() {
    log "Setting up Minikube cluster: ${CLUSTER_NAME}"

    if minikube status -p ${CLUSTER_NAME} >/dev/null 2>&1; then
        warn "Cluster already exists, deleting..."
        minikube delete -p ${CLUSTER_NAME}
    fi

    minikube start -p ${CLUSTER_NAME} \
        --memory=8192 \
        --cpus=4

    kubectl config use-context ${CLUSTER_NAME}

    log "Cluster ready ✓"
}

deploy_elasticsearch() {
    log "Deploying Elasticsearch..."

    helm repo add elastic https://helm.elastic.co 2>/dev/null || true
    helm repo update elastic >/dev/null

    helm upgrade --install elasticsearch elastic/elasticsearch \
        --namespace elasticsearch \
        --create-namespace \
        --set imageTag=8.16.1 \
        --set replicas=1 \
        --set minimumMasterNodes=1 \
        --set resources.requests.cpu=100m \
        --set resources.requests.memory=512Mi \
        --set persistence.enabled=true \
        --set volumeClaimTemplate.resources.requests.storage=5Gi \
        --wait

    log "Pre-creating tenant data streams..."
    ES_USER=$(kubectl get secret -n elasticsearch elasticsearch-master-credentials \
        -o jsonpath='{.data.username}' | base64 -d)
    ES_PASS=$(kubectl get secret -n elasticsearch elasticsearch-master-credentials \
        -o jsonpath='{.data.password}' | base64 -d)
    for idx in tenant-a-logs tenant-b-logs; do
        kubectl exec -n elasticsearch elasticsearch-master-0 -c elasticsearch -- \
            curl -fsS -k -u "${ES_USER}:${ES_PASS}" \
            -X PUT "https://localhost:9200/_index_template/${idx}-tmpl" \
            -H 'Content-Type: application/json' \
            -d "{\"index_patterns\":[\"${idx}\"],\"data_stream\":{},\"priority\":500}" >/dev/null
        kubectl exec -n elasticsearch elasticsearch-master-0 -c elasticsearch -- \
            curl -fsS -k -u "${ES_USER}:${ES_PASS}" \
            -X PUT "https://localhost:9200/_data_stream/${idx}" >/dev/null
    done

    log "Elasticsearch deployed ✓"
}

deploy_telemetry_controller() {
    log "Deploying Telemetry Controller..."

    helm upgrade --install telemetry-controller \
        oci://ghcr.io/kube-logging/helm-charts/telemetry-controller \
        --namespace telemetry-controller-system \
        --create-namespace \
        --wait

    kubectl create namespace collector --dry-run=client -o yaml | kubectl apply -f -

    log "Telemetry Controller deployed ✓"
}

create_tenant_namespaces() {
    log "Creating tenant namespaces..."

    for tenant in a b; do
        kubectl create namespace "tenant-${tenant}" \
            --dry-run=client -o yaml | kubectl apply -f -
        kubectl label namespace "tenant-${tenant}" \
            "tenant=${tenant}" --overwrite
    done

    log "Tenant namespaces ready ✓"
}

deploy_log_generators() {
    log "Deploying log-generator into each tenant namespace..."

    for tenant in a b; do
        helm upgrade --install "log-generator-${tenant}" \
            oci://ghcr.io/kube-logging/helm-charts/log-generator \
            --namespace "tenant-${tenant}" \
            --set app.eventPerSec=10 \
            --wait
    done

    log "Log generators deployed ✓"
}

apply_telemetry_crds() {
    log "Applying telemetry-controller CRDs (the ~50 lines of intent)..."

    kubectl apply -f "${MANIFESTS}/collector.yaml"
    kubectl apply -f "${MANIFESTS}/tenants.yaml"
    kubectl apply -f "${MANIFESTS}/subscriptions.yaml"
    kubectl apply -f "${MANIFESTS}/outputs.yaml"

    log "Waiting for telemetry-controller to reconcile the OpenTelemetryCollector resource..."
    for _ in $(seq 1 60); do
        kubectl get opentelemetrycollector -n collector 2>/dev/null | grep -q '\bcluster\b' && break
        sleep 2
    done

    log "Waiting for generated OTel Collector pod(s) to be Ready..."
    for _ in $(seq 1 60); do
        kubectl get pod -n collector \
            -l app.kubernetes.io/managed-by=opentelemetry-operator 2>/dev/null \
            | grep -q . && break
        sleep 2
    done
    kubectl wait --for=condition=Ready \
        -n collector pod \
        -l app.kubernetes.io/managed-by=opentelemetry-operator \
        --timeout=180s

    log "CRDs applied and Collector running ✓"
}

verify_pipeline() {
    log "Verifying end-to-end pipeline..."
    sleep 15

    ES_USER=$(kubectl get secret -n elasticsearch elasticsearch-master-credentials \
        -o jsonpath='{.data.username}' | base64 -d)
    ES_PASS=$(kubectl get secret -n elasticsearch elasticsearch-master-credentials \
        -o jsonpath='{.data.password}' | base64 -d)

    log "Tenant indices/data streams in Elasticsearch:"
    kubectl exec -n elasticsearch elasticsearch-master-0 -c elasticsearch -- \
        curl -fsS -k -u "${ES_USER}:${ES_PASS}" \
        'https://localhost:9200/_cat/indices?v' | grep tenant || \
        warn "No tenant indices found yet..."

    log "Sample doc from tenant-a-logs:"
    kubectl exec -n elasticsearch elasticsearch-master-0 -c elasticsearch -- \
        curl -fsS -k -u "${ES_USER}:${ES_PASS}" \
        'https://localhost:9200/tenant-a-logs/_search?size=1&pretty' \
        | jq '._source' || true

    log "Pipeline verification done ✓"
}

setup_cluster
deploy_elasticsearch
deploy_telemetry_controller
create_tenant_namespaces
deploy_log_generators
apply_telemetry_crds
verify_pipeline
log "Setup complete!"
