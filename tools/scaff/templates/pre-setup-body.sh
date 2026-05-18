CLUSTER_NAME="TODO-CLUSTER"

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

setup_cluster

log "Setup complete!"
