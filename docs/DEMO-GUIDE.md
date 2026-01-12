# 🎬 Hybrid Cloud Project Demo Guide

This guide provides a structured walkthrough for demonstrating the **DevSecOps Hybrid Cloud CI/CD Pipeline**.

## 🏗️ Demo Setup

Before presenting, ensure you have a clean environment:

```bash
# Stop any existing services
docker-compose -f docker-compose.demo.yml down -v

# Start the demo (takes 5-10 mins on first run)
chmod +x demo.sh
./demo.sh
```

## 📍 Step-by-Step Walkthrough

### 1. The Big Picture (Architecture)
*   **Show**: The architecture diagram in `README.md`.
*   **Narrative**: Explain the Hybrid Cloud setup. "This project bridges OpenStack (Private) and AWS (Public) using a secure VPN. We emphasize DevSecOps by injecting security at every stage."

### 2. Local Environment (The App)
*   **Open**: `http://localhost:3000`
*   **Show**: The FoodHub frontend interacting with the 3 backend services.
*   **Key Point**: "Even in a hybrid setup, local development remains seamless using Docker Compose."

### 3. CI/CD Orchestration (Jenkins)
*   **Open**: `http://localhost:8080` (admin/admin123)
*   **Show**: The `FoodHub-Hybrid-Pipeline`.
*   **Narrative**: "Jenkins acts as our brain, orchestrating builds, security scans, and cross-cloud deployments."
*   **Technical Detail**: Mention `Jenkinsfile.hybrid-cloud` and how it handles parallel builds for different clouds.

### 4. Security Integration (SonarQube & Trivy)
*   **Open**: `http://localhost:9000`
*   **Show**: Code quality metrics and vulnerability reports.
*   **Narrative**: "We don't just deploy; we verify. Every commit is scanned for bugs by SonarQube and for container vulnerabilities by Trivy."

### 5. Multi-Cloud Readiness (K8s Manifests)
*   **Open**: `k8s/deployments/overlays/` in your editor.
*   **Show**: The difference between `aws/kustomization.yaml` and `openstack/kustomization.yaml`.
*   **Narrative**: "Using Kustomize, we use the same base code but tailor configurations for each cloud (e.g., LoadBalancers for AWS, NodePorts for OpenStack)."

## 💡 Key Talking Points for Demo

1.  **Hybrid Connectivity**: "The cross-cloud VPN ensures that AWS services can talk to OpenStack databases securely."
2.  **GitOps Workflow**: "When we push code, Jenkins updates our GitOps repo. Tools like ArgoCD (optional) would then sync those changes to both clusters."
3.  **Security Gates**: "If a high-severity vulnerability is found by Trivy, the pipeline stops automatically. We never ship insecure code."
4.  **Scalability**: "We can burst our Frontend to AWS during high traffic while keeping sensitive user data in our private OpenStack cloud."

## 🧹 Cleanup
After the demo, clean up resources:
```bash
docker-compose -f docker-compose.demo.yml down
```
