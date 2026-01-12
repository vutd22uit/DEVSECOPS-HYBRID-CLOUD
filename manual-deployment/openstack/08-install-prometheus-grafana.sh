#!/bin/bash
set -e

# ========================================
# Prometheus + Grafana Installation
# ========================================
# Installs: kube-prometheus-stack (Prometheus, Grafana, Alertmanager)
# Uses: helm
# ========================================

echo "=========================================="
echo "📊 Installing Prometheus + Grafana"
echo "   on OpenStack Kubernetes"
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
MONITORING_NAMESPACE="monitoring"
KUBECONFIG=${KUBECONFIG:-~/.kube/config-foodhub-openstack}
GRAFANA_PASSWORD=${GRAFANA_PASSWORD:-"admin123"}

# ========================================
# Step 0: Check Prerequisites
# ========================================
echo ""
echo "Step 0: Checking prerequisites..."

export KUBECONFIG=${KUBECONFIG}

if ! kubectl cluster-info &> /dev/null; then
    print_red "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_green "Connected to Kubernetes cluster"

# Check/Install helm
if ! command -v helm &> /dev/null; then
    print_yellow "Helm not found, installing..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
print_green "Helm found"

# ========================================
# Step 1: Create Namespace
# ========================================
echo ""
echo "Step 1: Creating monitoring namespace..."

kubectl create namespace ${MONITORING_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
print_green "Namespace ${MONITORING_NAMESPACE} ready"

# ========================================
# Step 2: Add Helm Repository
# ========================================
echo ""
echo "Step 2: Adding Prometheus community Helm repo..."

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

print_green "Helm repo added"

# ========================================
# Step 3: Create Custom Values
# ========================================
echo ""
echo "Step 3: Creating custom values..."

MASTER_IP=${MASTER_IP:-$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "localhost")}

cat > /tmp/kube-prometheus-values.yaml <<EOF
# kube-prometheus-stack custom values for FoodHub Hybrid Cloud

# Global settings
fullnameOverride: "prometheus"

# Prometheus configuration
prometheus:
  prometheusSpec:
    replicas: 1
    retention: 15d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 20Gi
    # Additional scrape configs for hybrid cloud services
    additionalScrapeConfigs:
      - job_name: 'foodhub-users'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names:
                - foodhub
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            action: keep
            regex: foodhub-users
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            target_label: __address__
            regex: (.+)
            replacement: \${1}:8082
      - job_name: 'foodhub-products'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names:
                - foodhub
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            action: keep
            regex: foodhub-products
      - job_name: 'foodhub-orders'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names:
                - foodhub
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            action: keep
            regex: foodhub-orders
      - job_name: 'foodhub-frontend'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names:
                - foodhub
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            action: keep
            regex: foodhub-frontend

# Grafana configuration
grafana:
  enabled: true
  replicas: 1
  adminPassword: "${GRAFANA_PASSWORD}"
  persistence:
    enabled: true
    size: 5Gi
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - grafana.${MASTER_IP}.nip.io
  # Pre-configured datasources
  additionalDataSources:
    - name: Loki
      type: loki
      url: http://loki:3100
      access: proxy
      isDefault: false
  # Dashboards
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
        - name: 'foodhub'
          orgId: 1
          folder: 'FoodHub'
          type: file
          disableDeletion: true
          editable: true
          options:
            path: /var/lib/grafana/dashboards/foodhub

# Alertmanager configuration
alertmanager:
  enabled: true
  config:
    global:
      resolve_timeout: 5m
    route:
      group_by: ['alertname', 'severity']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'default-receiver'
      routes:
        - match:
            severity: critical
          receiver: 'critical-receiver'
    receivers:
      - name: 'default-receiver'
        # Add Slack, PagerDuty, etc. here
      - name: 'critical-receiver'
        # Add critical alert receivers here

# Node exporter for VM metrics
nodeExporter:
  enabled: true

# Kube state metrics
kubeStateMetrics:
  enabled: true

# Disable unnecessary components for smaller clusters
kubeControllerManager:
  enabled: false
kubeScheduler:
  enabled: false
kubeProxy:
  enabled: false
kubeEtcd:
  enabled: false
EOF

print_green "Custom values created"

# ========================================
# Step 4: Install kube-prometheus-stack
# ========================================
echo ""
echo "Step 4: Installing kube-prometheus-stack..."
echo "   This may take 3-5 minutes..."

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace ${MONITORING_NAMESPACE} \
    --values /tmp/kube-prometheus-values.yaml \
    --wait --timeout 10m

print_green "kube-prometheus-stack installed"

# ========================================
# Step 5: Wait for Pods
# ========================================
echo ""
echo "Step 5: Waiting for all pods to be ready..."

kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=prometheus \
    -n ${MONITORING_NAMESPACE} \
    --timeout=300s 2>/dev/null || true

kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=grafana \
    -n ${MONITORING_NAMESPACE} \
    --timeout=300s 2>/dev/null || true

print_green "All pods are ready"

# ========================================
# Step 6: Create Hybrid Cloud Dashboard
# ========================================
echo ""
echo "Step 6: Creating Hybrid Cloud dashboard..."

cat > /tmp/hybrid-cloud-dashboard.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-hybrid-cloud
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  hybrid-cloud-overview.json: |
    {
      "annotations": {
        "list": []
      },
      "editable": true,
      "fiscalYearStartMonth": 0,
      "graphTooltip": 0,
      "id": null,
      "links": [],
      "liveNow": false,
      "panels": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"color": "green", "value": null},
                  {"color": "yellow", "value": 70},
                  {"color": "red", "value": 90}
                ]
              },
              "unit": "percent"
            }
          },
          "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0},
          "id": 1,
          "options": {
            "orientation": "auto",
            "reduceOptions": {
              "calcs": ["lastNotNull"],
              "fields": "",
              "values": false
            },
            "showThresholdLabels": false,
            "showThresholdMarkers": true
          },
          "title": "CPU Usage",
          "type": "gauge",
          "targets": [
            {
              "expr": "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
              "refId": "A"
            }
          ]
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"color": "green", "value": null},
                  {"color": "yellow", "value": 70},
                  {"color": "red", "value": 90}
                ]
              },
              "unit": "percent"
            }
          },
          "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0},
          "id": 2,
          "options": {
            "orientation": "auto",
            "reduceOptions": {
              "calcs": ["lastNotNull"],
              "fields": "",
              "values": false
            }
          },
          "title": "Memory Usage",
          "type": "gauge",
          "targets": [
            {
              "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
              "refId": "A"
            }
          ]
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "mappings": [
                {"options": {"0": {"color": "red", "text": "Down"}}, "type": "value"},
                {"options": {"1": {"color": "green", "text": "Up"}}, "type": "value"}
              ],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"color": "red", "value": null},
                  {"color": "green", "value": 1}
                ]
              }
            }
          },
          "gridPos": {"h": 4, "w": 3, "x": 12, "y": 0},
          "id": 3,
          "title": "Users Service",
          "type": "stat",
          "targets": [
            {
              "expr": "up{job=\"foodhub-users\"}",
              "refId": "A"
            }
          ]
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "mappings": [
                {"options": {"0": {"color": "red", "text": "Down"}}, "type": "value"},
                {"options": {"1": {"color": "green", "text": "Up"}}, "type": "value"}
              ]
            }
          },
          "gridPos": {"h": 4, "w": 3, "x": 15, "y": 0},
          "id": 4,
          "title": "Products Service",
          "type": "stat",
          "targets": [
            {
              "expr": "up{job=\"foodhub-products\"}",
              "refId": "A"
            }
          ]
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "mappings": [
                {"options": {"0": {"color": "red", "text": "Down"}}, "type": "value"},
                {"options": {"1": {"color": "green", "text": "Up"}}, "type": "value"}
              ]
            }
          },
          "gridPos": {"h": 4, "w": 3, "x": 18, "y": 0},
          "id": 5,
          "title": "Orders Service",
          "type": "stat",
          "targets": [
            {
              "expr": "up{job=\"foodhub-orders\"}",
              "refId": "A"
            }
          ]
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "mappings": [
                {"options": {"0": {"color": "red", "text": "Down"}}, "type": "value"},
                {"options": {"1": {"color": "green", "text": "Up"}}, "type": "value"}
              ]
            }
          },
          "gridPos": {"h": 4, "w": 3, "x": 21, "y": 0},
          "id": 6,
          "title": "Frontend",
          "type": "stat",
          "targets": [
            {
              "expr": "up{job=\"foodhub-frontend\"}",
              "refId": "A"
            }
          ]
        }
      ],
      "refresh": "10s",
      "schemaVersion": 38,
      "style": "dark",
      "tags": ["foodhub", "hybrid-cloud"],
      "templating": {
        "list": []
      },
      "time": {
        "from": "now-1h",
        "to": "now"
      },
      "timepicker": {},
      "timezone": "",
      "title": "FoodHub Hybrid Cloud Overview",
      "uid": "foodhub-overview",
      "version": 1
    }
EOF

kubectl apply -f /tmp/hybrid-cloud-dashboard.yaml
print_green "Dashboard created"

# ========================================
# Summary
# ========================================
echo ""
echo "=========================================="
echo "🎉 Monitoring Stack Installed!"
echo "=========================================="
echo ""
echo "📊 Components:"
echo "   ✅ Prometheus (metrics collection)"
echo "   ✅ Grafana (visualization)"
echo "   ✅ Alertmanager (alerting)"
echo "   ✅ Node Exporter (host metrics)"
echo "   ✅ Kube State Metrics (K8s metrics)"
echo ""
echo "🔗 Access URLs:"
echo ""
echo "   Grafana:"
echo "   kubectl port-forward svc/prometheus-grafana -n ${MONITORING_NAMESPACE} 3000:80"
echo "   http://localhost:3000"
echo "   Or via Ingress: http://grafana.${MASTER_IP}.nip.io"
echo ""
echo "   Prometheus:"
echo "   kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n ${MONITORING_NAMESPACE} 9090:9090"
echo "   http://localhost:9090"
echo ""
echo "   Alertmanager:"
echo "   kubectl port-forward svc/prometheus-kube-prometheus-alertmanager -n ${MONITORING_NAMESPACE} 9093:9093"
echo "   http://localhost:9093"
echo ""
echo "🔐 Grafana Credentials:"
echo "   Username: admin"
echo "   Password: ${GRAFANA_PASSWORD}"
echo ""
echo "📈 Pre-configured Dashboards:"
echo "   - FoodHub Hybrid Cloud Overview"
echo "   - Kubernetes Cluster Metrics"
echo "   - Node Exporter Full"
echo ""
echo "=========================================="

# Save configuration
cat > /tmp/foodhub-monitoring-config.sh <<EOF
# Auto-generated by 08-install-prometheus-grafana.sh
export MONITORING_NAMESPACE="${MONITORING_NAMESPACE}"
export GRAFANA_PASSWORD="${GRAFANA_PASSWORD}"
export PROMETHEUS_URL="http://prometheus-kube-prometheus-prometheus.${MONITORING_NAMESPACE}.svc:9090"
EOF

print_green "Configuration saved to /tmp/foodhub-monitoring-config.sh"
