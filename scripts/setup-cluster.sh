#!/bin/bash
# ══════════════════════════════════════════════════════════════
# DevSecOps Local Cluster Setup Script
# ══════════════════════════════════════════════════════════════
# This script bootstraps a local Kubernetes cluster using k3d,
# installs Falco for runtime security monitoring, and deploys
# the DevSecOps demo application.
#
# Prerequisites:
#   - Docker (running)
#   - k3d (https://k3d.io)
#   - kubectl
#   - helm
# ══════════════════════════════════════════════════════════════

set -euo pipefail

# ── Configuration ──
CLUSTER_NAME="devsecops-lab"
APP_NAMESPACE="devsecops"
FALCO_NAMESPACE="falco"
IMAGE_NAME="devsecops-app"
IMAGE_TAG="1.0.0"

# ── Colors for output ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[ℹ]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# ── Step 0: Check prerequisites ──
print_header "Step 0: Checking Prerequisites"

check_command() {
    if command -v "$1" &> /dev/null; then
        print_step "$1 is installed ($(command -v $1))"
    else
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

check_command docker
check_command k3d
check_command kubectl
check_command helm

# Check Docker is running
if docker info &> /dev/null; then
    print_step "Docker daemon is running"
else
    print_error "Docker daemon is not running. Please start Docker."
    exit 1
fi

# ── Step 1: Create k3d cluster ──
print_header "Step 1: Creating k3d Kubernetes Cluster"

# Delete existing cluster if it exists
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    print_warn "Cluster '$CLUSTER_NAME' already exists. Deleting..."
    k3d cluster delete "$CLUSTER_NAME"
fi

k3d cluster create "$CLUSTER_NAME" \
    --agents 2 \
    --port "8080:80@loadbalancer" \
    --port "8443:443@loadbalancer" \
    --wait

print_step "k3d cluster '$CLUSTER_NAME' created successfully"

# Verify cluster
kubectl cluster-info
kubectl get nodes
echo ""

# ── Step 2: Build and import application image ──
print_header "Step 2: Building & Importing Application Image"

# Build the Docker image
print_info "Building Docker image..."
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" ./app/
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "trusted-registry.company.com/${IMAGE_NAME}:${IMAGE_TAG}"

# Import image into k3d cluster
print_info "Importing image into k3d cluster..."
k3d image import "trusted-registry.company.com/${IMAGE_NAME}:${IMAGE_TAG}" -c "$CLUSTER_NAME"

print_step "Application image built and imported"

# ── Step 3: Deploy application ──
print_header "Step 3: Deploying Application to Kubernetes"

# Create namespace
kubectl apply -f k8s/namespace.yaml

# Deploy application
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Wait for deployment
print_info "Waiting for deployment to be ready..."
kubectl rollout status deployment/devsecops-app -n "$APP_NAMESPACE" --timeout=120s

print_step "Application deployed successfully"
kubectl get pods -n "$APP_NAMESPACE"

# ── Step 4: Install Falco ──
print_header "Step 4: Installing Falco Runtime Security"

# Add Falco Helm repo
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# Create Falco namespace
kubectl create namespace "$FALCO_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Install Falco with custom values
print_info "Installing Falco via Helm (this may take a few minutes)..."
helm upgrade --install falco falcosecurity/falco \
    --namespace "$FALCO_NAMESPACE" \
    -f falco/falco-values.yaml \
    --wait \
    --timeout 5m

print_step "Falco installed successfully"
kubectl get pods -n "$FALCO_NAMESPACE"

# ── Step 5: Verify Setup ──
print_header "Step 5: Verifying Setup"

echo ""
echo -e "${GREEN}Cluster Resources:${NC}"
kubectl get all -n "$APP_NAMESPACE"
echo ""
echo -e "${GREEN}Falco Pods:${NC}"
kubectl get pods -n "$FALCO_NAMESPACE"
echo ""

# ── Summary ──
print_header "Setup Complete! 🎉"

echo -e "  ${GREEN}Cluster:${NC}     $CLUSTER_NAME"
echo -e "  ${GREEN}App:${NC}         $APP_NAMESPACE namespace"
echo -e "  ${GREEN}Falco:${NC}       $FALCO_NAMESPACE namespace"
echo ""
echo -e "  ${YELLOW}Next Steps:${NC}"
echo -e "    1. Test Falco detection:"
echo -e "       ${CYAN}./scripts/demo-falco.sh${NC}"
echo ""
echo -e "    2. Manually test shell detection:"
echo -e "       Terminal 1: ${CYAN}kubectl logs -n falco -l app.kubernetes.io/name=falco -f${NC}"
echo -e "       Terminal 2: ${CYAN}kubectl exec -it \$(kubectl get pods -n devsecops -o jsonpath='{.items[0].metadata.name}') -n devsecops -- /bin/sh${NC}"
echo ""
echo -e "    3. Access the application:"
echo -e "       ${CYAN}kubectl port-forward svc/devsecops-app-service -n devsecops 3000:80${NC}"
echo -e "       Then open: ${CYAN}http://localhost:3000${NC}"
echo ""
