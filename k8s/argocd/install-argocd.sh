#!/bin/bash
set -e

echo "=========================================="
echo "Installing ArgoCD for Hybrid Cloud"
echo "=========================================="

# Configuration
ARGOCD_VERSION="v2.10.0"
NAMESPACE="argocd"

# Create namespace
echo "📦 Creating ArgoCD namespace..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo "📦 Installing ArgoCD ${ARGOCD_VERSION}..."
kubectl apply -n ${NAMESPACE} -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n ${NAMESPACE}

# Get initial admin password
echo "🔑 Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n ${NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "=========================================="
echo "✅ ArgoCD Installation Complete!"
echo "=========================================="
echo ""
echo "Access ArgoCD:"
echo "  1. Port forward:"
echo "     kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "  2. Login credentials:"
echo "     Username: admin"
echo "     Password: ${ARGOCD_PASSWORD}"
echo ""
echo "  3. Change password after first login:"
echo "     argocd account update-password"
echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Install ArgoCD CLI:"
echo "   curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"
echo "   sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd"
echo ""
echo "2. Login via CLI:"
echo "   argocd login localhost:8080 --username admin --password ${ARGOCD_PASSWORD} --insecure"
echo ""
echo "3. Register clusters:"
echo "   # For EKS cluster:"
echo "   argocd cluster add foodhub-eks --name foodhub-eks"
echo ""
echo "   # For OpenStack K8s (from master node):"
echo "   argocd cluster add foodhub-openstack --name foodhub-openstack"
echo ""
echo "4. Apply multi-cluster configurations:"
echo "   kubectl apply -f k8s/argocd/multi-cluster/"
echo ""
echo "5. Deploy ApplicationSet:"
echo "   kubectl apply -f k8s/argocd/multi-cluster/applicationset-hybrid.yaml"
echo ""
echo "=========================================="
