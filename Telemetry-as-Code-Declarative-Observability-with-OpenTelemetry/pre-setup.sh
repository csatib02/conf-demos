#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="sreday-demo"
GITOPS="${SCRIPT_DIR}/gitops"

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

    log "Enabling ingress addon..."
    minikube addons enable ingress -p ${CLUSTER_NAME}
    minikube addons enable metrics-server -p ${CLUSTER_NAME}

    kubectl config use-context ${CLUSTER_NAME}

    log "Cluster ready ✓"
}

setup_tunnel() {
    log "Setting up Minikube tunnel (requires sudo)..."

    if pgrep -f "minikube tunnel --profile ${CLUSTER_NAME}" > /dev/null; then
        sudo pkill -f "minikube tunnel --profile ${CLUSTER_NAME}"
        log "Existing Minikube tunnel process killed."
    fi

    if ! sudo -v; then
        warn "sudo authentication failed"
        exit 1
    fi

    sudo minikube tunnel --profile "${CLUSTER_NAME}" > /dev/null 2>&1 &
}

deploy_argocd() {
    log "Deploying Argo CD..."

    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    log "Argo CD deployed ✓"
}

deploy_observability() {
    log "Deploying observability stack..."

    helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
    helm repo update

    log "Installing Loki..."
    helm upgrade --install loki grafana/loki \
        --version 6.44.0 \
        --namespace monitoring \
        --create-namespace \
        -f "${SCRIPT_DIR}/loki-values.yaml" \
        --wait

    log "Installing Prometheus..."
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.retention=2h \
        --set prometheus.prometheusSpec.scrapeInterval=10s \
        --set grafana.enabled=false \
        --wait

    log "Deploying Perses-operator..."

    if [ ! -d "./perses-operator" ]; then
        warn "perses-operator is under heavy development, I had to make some manual changes to make it work with version: v0.2.0, that might be already fixed on latest main."
    else
        cd ./perses-operator
        make install && make deploy
        cd -
    fi
    make install && make deploy
    cd -

    log "Observability stack deployed ✓"
}

deploy_telemetry_controller() {
    log "Deploying Telemetry Controller..."

    helm upgrade --install telemetry-controller oci://ghcr.io/kube-logging/helm-charts/telemetry-controller \
        --namespace telemetry-controller-system \
        --create-namespace \
        --wait

    kubectl create namespace collector --dry-run=client -o yaml | kubectl apply -f -

    log "Telemetry Controller deployed ✓"
}

deploy_demo_apps() {
    log "Deploying demo applications..."

    cd ${GITOPS}/apps/frontend/src/sreday
    docker build -t frontend-ab-test:latest .
    cd -
    cd ${GITOPS}/apps/frontend/src/log-viewer
    docker build -t log-viewer:latest .
    cd -

    minikube image load frontend-ab-test:latest -p ${CLUSTER_NAME}
    minikube image load log-viewer:latest -p ${CLUSTER_NAME}

    kubectl create namespace frontend --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace platform --dry-run=client -o yaml | kubectl apply -f -

    kubectl label namespace frontend nsSelector=team-frontend --overwrite
    kubectl label namespace platform nsSelector=team-platform --overwrite

    kubectl apply -f ${GITOPS}/apps/frontend/

    log "Waiting for applications to be ready..."
    kubectl wait --for=condition=available deployment/frontend -n frontend --timeout=120s

    log "Demo applications deployed ✓"
}

setup_argocd_apps() {
    log "Configuring Argo CD Applications..."

    kubectl apply -f ${GITOPS}/argocd/applications/

    sleep 10

    log "Argo CD Applications configured ✓"
}

setup_service_ingresses() {
    log "Setting up service ingresses..."

    kubectl apply -f ${GITOPS}/bootstrap/service-ingress.yaml

    log "Service ingresses set up ✓"
}

setup_service_monitors() {
    log "Setting up service monitors..."

    kubectl apply -f ${GITOPS}/bootstrap/service-monitor.yaml

    log "Service monitors set up ✓"
}

show_urls() {
    log "=================================================="
    log "Demo Environment Ready!"
    log "=================================================="
    echo ""

    echo "Argo CD UI:"
    echo "  URL: http://argocd.local"
    echo "  User: admin"
    echo "  Pass: $(kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
    echo ""

    echo "Prometheus UI:"
    echo "  URL: http://prometheus.local"
    echo ""

    echo "Perses UI:"
    echo "  URL: http://perses.local"
    echo ""

    echo "Frontend App:"
    echo "  URL: http://frontend.local"
    echo ""

    log "=================================================="
}

setup_cluster
setup_tunnel
deploy_argocd
deploy_observability
deploy_telemetry_controller
deploy_demo_apps
setup_argocd_apps
setup_service_ingresses
setup_service_monitors
show_urls
log "Setup complete!"
