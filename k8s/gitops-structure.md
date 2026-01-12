# GitOps Repository Structure

This document describes the expected structure for your GitOps configuration repository.

## Repository: `dacn-config`

The GitOps repository should be organized with separate directories for each cloud provider and service.

```
dacn-config/
├── README.md
├── services/
│   ├── users/
│   │   ├── aws/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── ingress.yaml
│   │   │   └── values.yaml
│   │   └── openstack/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml
│   │       └── values.yaml
│   ├── products/
│   │   ├── aws/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── ingress.yaml
│   │   │   └── values.yaml
│   │   └── openstack/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml
│   │       └── values.yaml
│   ├── orders/
│   │   ├── aws/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── ingress.yaml
│   │   │   └── values.yaml
│   │   └── openstack/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml
│   │       └── values.yaml
│   └── frontend/
│       ├── aws/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   ├── ingress.yaml
│       │   └── values.yaml
│       └── openstack/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           └── values.yaml
├── argocd/
│   ├── applications/
│   │   ├── users-aws.yaml
│   │   ├── users-openstack.yaml
│   │   ├── products-aws.yaml
│   │   ├── products-openstack.yaml
│   │   ├── orders-aws.yaml
│   │   ├── orders-openstack.yaml
│   │   ├── frontend-aws.yaml
│   │   └── frontend-openstack.yaml
│   └── applicationsets/
│       └── foodhub-hybrid.yaml
└── infrastructure/
    ├── namespaces/
    │   └── foodhub.yaml
    ├── configmaps/
    └── secrets/
```

## Key Points

1. **Separation by Cloud Provider**: Each service has separate configurations for AWS and OpenStack
2. **ArgoCD Applications**: Pre-configured Application manifests for automated deployment
3. **Values Files**: The pipeline updates `values.yaml` to change image tags
4. **Infrastructure**: Common infrastructure components shared across services

## Creating the Repository

```bash
# 1. Create new repository on GitHub
# Repository name: dacn-config

# 2. Clone and initialize
git clone https://github.com/NgHVu/dacn-config.git
cd dacn-config

# 3. Use the example manifests from this project
# Copy from /k8s/examples/ to the GitOps repo

# 4. Commit and push
git add .
git commit -m "Initial GitOps structure"
git push origin main
```

## Jenkins Integration

The Jenkinsfile updates the `values.yaml` file in each service's cloud-specific directory:

```groovy
// Example update path for AWS
services/users/aws/values.yaml

// Example update path for OpenStack  
services/users/openstack/values.yaml
```

The `updateGitOps()` function in the Jenkinsfile handles this automatically.
