#!/bin/bash
set -e

# ========================================
# ArgoCD Installation on OpenStack K8s
# ========================================
# Installs: ArgoCD for GitOps deployment
# Uses: kubectl, helm
# ========================================

echo "=========================================="
echo "🔄 Installing ArgoCD on OpenStack K8s"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_green() { echo -e "${GREEN}✅ $1${NC}"; }
print_yellow() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_red() { echo -e "${RED}❌ $1${NC}"; }

# Load environment
if [ -f ~/.openstack-foodhub.env ]; then
    source ~/.openstack-foodhub.env
fi

# Configuration
ARGOCD_VERSION=${ARGOCD_VERSION:-"v2.10.0"}
ARGOCD_NAMESPACE="argocd"
KUBECONFIG=${KUBECONFIG:-~/.kube/config-foodhub-openstack}

# ========================================
# Step 0: Check Prerequisites
# ========================================
echo ""
echo "Step 0: Checking prerequisites..."

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    print_red "kubectl is not installed"
    exit 1
fi

# Check cluster connection
export KUBECONFIG=${KUBECONFIG}
if ! kubectl cluster-info &> /dev/null; then
    print_red "Cannot connect to Kubernetes cluster"
    echo "Check KUBECONFIG: ${KUBECONFIG}"
    exit 1
fi
print_green "Connected to Kubernetes cluster"

# Check helm
if ! command -v helm &> /dev/null; then
    print_yellow "Helm not found, installing..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
print_green "Helm found"

# ========================================
# Step 1: Create Namespace
# ========================================
echo ""
echo "Step 1: Creating ArgoCD namespace..."

kubectl create namespace ${ARGOCD_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
print_green "Namespace ${ARGOCD_NAMESPACE} ready"

# ========================================
# Step 2: Install ArgoCD
# ========================================
echo ""
echo "Step 2: Installing ArgoCD ${ARGOCD_VERSION}..."

# Option 1: Install using manifests
kubectl apply -n ${ARGOCD_NAMESPACE} -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

# Wait for ArgoCD to be ready
echo ""
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n ${ARGOCD_NAMESPACE}
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n ${ARGOCD_NAMESPACE}
kubectl wait --for=condition=available --timeout=300s deployment/argocd-applicationset-controller -n ${ARGOCD_NAMESPACE}

print_green "ArgoCD installed successfully"

# ========================================
# Step 3: Patch ArgoCD for Insecure Mode (Optional)
# ========================================
echo ""
echo "Step 3: Configuring ArgoCD server..."

# Patch for insecure mode (no TLS) - useful for development
kubectl patch deployment argocd-server -n ${ARGOCD_NAMESPACE} \
    --type='json' \
    -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]' || true

print_green "ArgoCD server configured"

# ========================================
# Step 4: Create Ingress (Optional)
# ========================================
echo ""
echo "Step 4: Creating Ingress for ArgoCD..."

# Get the master node IP for ingress host
MASTER_IP=${MASTER_IP:-$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "argocd.local")}

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: ${ARGOCD_NAMESPACE}
  annotations:
    nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
    nginx.ingress.kubernetes.io/ssl-passthrough: "false"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  ingressClassName: nginx
  rules:
    - host: argocd.${MASTER_IP}.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
EOF

print_green "Ingress created"

# ========================================
# Step 5: Get Admin Password
# ========================================
echo ""
echo "Step 5: Getting admin password..."

# Wait for secret to be created
sleep 5
ARGOCD_PASSWORD=$(kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

print_green "Admin password retrieved"

# ========================================
# Step 6: Install ArgoCD CLI (Optional)
# ========================================
echo ""
echo "Step 6: Installing ArgoCD CLI..."

if ! command -v argocd &> /dev/null; then
    curl -sSL -o /tmp/argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64
    sudo install -m 555 /tmp/argocd-linux-amd64 /usr/local/bin/argocd
    rm -f /tmp/argocd-linux-amd64
    print_green "ArgoCD CLI installed"
else
    print_yellow "ArgoCD CLI already installed"
fi

# ========================================
# Step 7: Configure GitOps Repository
# ========================================
echo ""
echo "Step 7: Creating GitOps repository secret..."

# Create template for GitOps repo secret
cat > /tmp/argocd-repo-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitops-repo
  namespace: ${ARGOCD_NAMESPACE}
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/YOUR_USERNAME/foodhub-gitops.git
  username: YOUR_USERNAME
  password: YOUR_GITHUB_TOKEN
EOF

print_yellow "GitOps repository secret template saved to /tmp/argocd-repo-secret.yaml"
echo "   Edit this file and apply: kubectl apply -f /tmp/argocd-repo-secret.yaml"

# ========================================
# Step 8: Create ApplicationSet for Hybrid Cloud
# ========================================
echo ""
echo "Step 8: Creating ApplicationSet for services..."

cat > /tmp/argocd-applicationset.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: foodhub-services
  namespace: ${ARGOCD_NAMESPACE}
spec:
  generators:
    - list:
        elements:
          - service: users
            port: "8082"
          - service: products
            port: "8083"
          - service: orders
            port: "8084"
          - service: frontend
            port: "3000"
  template:
    metadata:
      name: 'foodhub-{{service}}'
      namespace: ${ARGOCD_NAMESPACE}
    spec:
      project: default
      source:
        repoURL: https://github.com/YOUR_USERNAME/foodhub-gitops.git
        targetRevision: main
        path: 'services/{{service}}/openstack'
      destination:
        server: https://kubernetes.default.svc
        namespace: foodhub
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
EOF

print_yellow "ApplicationSet template saved to /tmp/argocd-applicationset.yaml"
echo "   Edit and apply after configuring GitOps repo"

# ========================================
# Summary
# ========================================
echo ""
echo "=========================================="
echo "🎉 ArgoCD Installation Complete!"
echo "=========================================="
echo ""
echo "📋 ArgoCD Details:"
echo "   Version:     ${ARGOCD_VERSION}"
echo "   Namespace:   ${ARGOCD_NAMESPACE}"
echo ""
echo "🔗 Access ArgoCD:"
echo ""
echo "   Option 1 - Port Forward:"
echo "   kubectl port-forward svc/argocd-server -n ${ARGOCD_NAMESPACE} 8443:443"
echo "   Then open: https://localhost:8443"
echo ""
echo "   Option 2 - Ingress (if configured):"
echo "   http://argocd.${MASTER_IP}.nip.io"
echo ""
echo "🔐 Login Credentials:"
echo "   Username: admin"
echo "   Password: ${ARGOCD_PASSWORD}"
echo ""
echo "⚠️  Please change the admin password after first login!"
echo ""
echo "📖 CLI Login:"
echo "   argocd login localhost:8443 --username admin --password '${ARGOCD_PASSWORD}' --insecure"
echo ""
echo "🔧 Next Steps:"
echo "   1. Edit /tmp/argocd-repo-secret.yaml with your GitOps repo"
echo "   2. kubectl apply -f /tmp/argocd-repo-secret.yaml"
echo "   3. Edit /tmp/argocd-applicationset.yaml"
echo "   4. kubectl apply -f /tmp/argocd-applicationset.yaml"
echo ""
echo "=========================================="

# Save configuration
cat > /tmp/foodhub-argocd-config.sh <<EOF
# Auto-generated by 07-install-argocd.sh
export ARGOCD_VERSION="${ARGOCD_VERSION}"
export ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE}"
export ARGOCD_PASSWORD="${ARGOCD_PASSWORD}"
EOF

print_green "Configuration saved to /tmp/foodhub-argocd-config.sh"
