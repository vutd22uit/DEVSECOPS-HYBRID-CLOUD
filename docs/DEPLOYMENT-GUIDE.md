# 🚀 Complete Deployment Guide for Hybrid Cloud CI/CD Pipeline

This guide will walk you through deploying and running the complete CI/CD pipeline for the FoodHub project.

## 📋 Prerequisites

### Required Software
- ✅ Docker Desktop (or Docker Engine + Docker Compose)
- ✅ Git
- ✅ AWS CLI (configured with credentials)
- ✅ kubectl (for Kubernetes management)
- ✅ Terraform (for infrastructure provisioning)

### Required Accounts & Access
- ✅ AWS Account with EKS cluster
- ✅ OpenStack environment (optional for hybrid deployment)
- ✅ GitHub account for GitOps repository
- ✅ Container registries (ECR on AWS, Harbor on OpenStack)

---

## 🏗️ Step 1: Initial Setup

### 1.1 Clone the Repository

```bash
git clone https://github.com/vutd22uit/DEVSECOPS-HYBRID-CLOUD.git
cd DEVSECOPS-HYBRID-CLOUD
```

### 1.2 Configure Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your actual credentials
nano .env
```

Fill in the following critical values:
- `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
- `HARBOR_REGISTRY_URL`, `HARBOR_USERNAME`, `HARBOR_PASSWORD` (if using OpenStack)
- `GITOPS_TOKEN` (GitHub Personal Access Token)
- `SONAR_TOKEN` (will be generated in Step 2)

### 1.3 Make Scripts Executable

```bash
chmod +x scripts/*.sh
chmod +x scripts/hybrid-cloud/*.sh
```

---

## 🐳 Step 2: Deploy Jenkins and SonarQube

### 2.1 Build and Start Services

```bash
# Build the custom Jenkins image
docker-compose build jenkins

# Start all services (Jenkins + SonarQube + PostgreSQL)
docker-compose up -d
```

### 2.2 Access Jenkins

1. Open browser: `http://localhost:8080`
2. Login with default credentials:
   - Username: `admin`
   - Password: `admin123` (change this immediately!)

### 2.3 Configure SonarQube

1. Open browser: `http://localhost:9000`
2. Login with default credentials:
   - Username: `admin`
   - Password: `admin` (you'll be prompted to change)
3. Generate a token:
   - Navigate to: **My Account** → **Security** → **Generate Token**
   - Name: `Jenkins Integration`
   - Copy the token and update `.env` file: `SONAR_TOKEN=squ_...`

### 2.4 Configure Jenkins Credentials

Go to **Manage Jenkins** → **Manage Credentials** → **Global** → **Add Credentials**

Create the following credentials:

#### AWS Credentials
- **Kind**: Secret text
- **ID**: `aws-access-key-id`
- **Secret**: Your AWS Access Key ID

- **Kind**: Secret text
- **ID**: `aws-secret-access-key`
- **Secret**: Your AWS Secret Access Key

#### Harbor Registry (if using OpenStack)
- **Kind**: Username with password
- **ID**: `harbor-credentials`
- **Username**: `admin`
- **Password**: Your Harbor password

- **Kind**: Secret text
- **ID**: `harbor-registry-url`
- **Secret**: `harbor.example.com` (your Harbor URL)

#### GitHub Personal Access Token
- **Kind**: Secret text
- **ID**: `github-pat`
- **Secret**: Your GitHub PAT

#### SonarQube Token
- **Kind**: Secret text
- **ID**: `sonar-token`
- **Secret**: Your SonarQube token

---

## 📦 Step 3: Setup GitOps Repository

### 3.1 Create GitOps Repository on GitHub

```bash
# Create a new repository named 'dacn-config' on GitHub
# Then clone it locally
git clone https://github.com/NgHVu/dacn-config.git
cd dacn-config
```

### 3.2 Copy Example Manifests

```bash
# Navigate back to the main project
cd ../DEVSECOPS-HYBRID-CLOUD

# Copy example manifests to GitOps repo
mkdir -p ../dacn-config/services/users/{aws,openstack}
cp k8s/examples/users-aws.yaml ../dacn-config/services/users/aws/
cp k8s/examples/users-openstack.yaml ../dacn-config/services/users/openstack/

# For each service, create the values.yaml that Jenkins will update
cat > ../dacn-config/services/users/aws/values.yaml << EOF
image:
  repository: 257394468168.dkr.ecr.ap-southeast-1.amazonaws.com/foodhub-users
  tag: latest
  pullPolicy: Always
EOF

cat > ../dacn-config/services/users/openstack/values.yaml << EOF
image:
  repository: harbor.example.com/foodhub/foodhub-users
  tag: latest
  pullPolicy: Always
EOF

# Create namespace
mkdir -p ../dacn-config/infrastructure/namespaces
cp k8s/examples/namespace.yaml ../dacn-config/infrastructure/namespaces/

# Commit and push
cd ../dacn-config
git add .
git commit -m "Initial GitOps structure"
git push origin main
```

### 3.3 Repeat for Other Services

Create similar structures for `products`, `orders`, and `frontend` services.

---

## 🔧 Step 4: Configure Jenkins Pipeline

### 4.1 Create Pipeline Job

1. In Jenkins, click **New Item**
2. Enter name: `FoodHub-Hybrid-Pipeline`
3. Select: **Pipeline**
4. Click: **OK**

### 4.2 Configure Pipeline

In the pipeline configuration:

1. **General Section**:
   - Check: "GitHub project"
   - Project URL: `https://github.com/vutd22uit/DEVSECOPS-HYBRID-CLOUD/`

2. **Build Triggers**:
   - Check: "GitHub hook trigger for GITScm polling"

3. **Pipeline Section**:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/vutd22uit/DEVSECOPS-HYBRID-CLOUD.git`
   - Branch: `*/main` (or your branch)
   - Script Path: `CICD/Jenkinsfile.hybrid-cloud`

4. Click **Save**

### 4.3 Configure SonarQube in Jenkins

1. Go to **Manage Jenkins** → **Configure System**
2. Scroll to **SonarQube servers**
3. Click **Add SonarQube**
   - Name: `sonarqube-local`
   - Server URL: `http://sonarqube:9000`
   - Server authentication token: Select the credential you created earlier

---

## 🚀 Step 5: Run the Pipeline

### 5.1 Trigger First Build

1. Go to your pipeline: **FoodHub-Hybrid-Pipeline**
2. Click **Build Now**
3. Watch the console output

### 5.2 Monitor Pipeline Stages

The pipeline will execute these stages:
1. ✅ **Initialize**: Setup environment, login to registries
2. ✅ **Build & Deploy Microservices**: 
   - Code analysis (SonarQube)
   - Security scan (Trivy)
   - Docker build & push
   - GitOps update
3. ✅ **Health Check**: Verify deployments

### 5.3 Expected Duration

- First build: ~15-20 minutes (downloads dependencies)
- Subsequent builds: ~5-10 minutes

---

## ✅ Step 6: Verify Deployment

### 6.1 Check Image Registries

**AWS ECR:**
```bash
aws ecr list-images --repository-name foodhub-users --region ap-southeast-1
```

**Harbor (if using OpenStack):**
- Visit: `http://harbor.example.com`
- Navigate to: **Projects** → **foodhub**
- Verify images are present

### 6.2 Check GitOps Repository

```bash
cd ../dacn-config
git pull origin main

# Verify image tags were updated
cat services/users/aws/values.yaml
```

You should see the new image tag from your build.

### 6.3 Check Kubernetes Deployment

```bash
# For AWS EKS
kubectl --context foodhub-eks get pods -n foodhub

# For OpenStack K8s
kubectl --context foodhub-openstack get pods -n foodhub
```

---

## 🔄 Step 7: Testing the Pipeline

### 7.1 Make a Code Change

```bash
cd DEVSECOPS-HYBRID-CLOUD

# Make a small change to a service
echo "// Pipeline test" >> services/users/src/main/java/com/foodhub/users/UsersApplication.java

# Commit and push
git add .
git commit -m "test: trigger pipeline"
git push origin main
```

### 7.2 Watch Auto-Trigger

If you configured GitHub webhooks:
- The pipeline should automatically trigger
- Check Jenkins UI for running build

### 7.3 Verify Changes Propagate

1. Check new images in registry
2. Verify GitOps repo updated
3. Check pods are rolling out in K8s

---

## 🎯 Deployment Modes

The pipeline supports three deployment modes (set in `CICD/Jenkinsfile.hybrid-cloud`):

### Mode 1: AWS Only
```groovy
environment {
    DEPLOYMENT_MODE = 'AWS'
}
```
- Builds and pushes to ECR only
- Deploys to EKS only

### Mode 2: OpenStack Only
```groovy
environment {
    DEPLOYMENT_MODE = 'OPENSTACK'
}
```
- Builds and pushes to Harbor only
- Deploys to OpenStack K8s only

### Mode 3: Hybrid (Default)
```groovy
environment {
    DEPLOYMENT_MODE = 'HYBRID'
}
```
- Builds and pushes to both ECR and Harbor
- Deploys to both EKS and OpenStack K8s

---

## 🛠️ Troubleshooting

### Jenkins Can't Access Docker

**Error**: `Cannot connect to Docker daemon`

**Solution**:
```bash
# Ensure Docker socket is mounted
docker-compose down
docker-compose up -d
```

### SonarQube Analysis Fails

**Error**: `Unable to reach SonarQube server`

**Solution**:
- Verify SonarQube is running: `docker-compose ps`
- Check network connectivity: `docker network inspect devsecops-hybrid-cloud_devops-network`
- Ensure Jenkins and SonarQube are on the same network

### AWS ECR Login Fails

**Error**: `Error saving credentials`

**Solution**:
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Update credentials in Jenkins
# Manage Jenkins → Manage Credentials → Update AWS credentials
```

### GitOps Update Fails

**Error**: `Permission denied (publickey)`

**Solution**:
- Verify GitHub PAT has `repo` scope
- Update credential in Jenkins with new PAT

---

## 📊 Monitoring & Logs

### View Jenkins Logs
```bash
docker logs jenkins-hybrid-cloud -f
```

### View SonarQube Logs
```bash
docker logs sonarqube-local -f
```

### Access Metrics
- **Jenkins**: http://localhost:8080/monitoring
- **SonarQube**: http://localhost:9000/projects

---

## 🎓 Next Steps

1. **Set up ArgoCD**: For automated GitOps deployment
2. **Configure Monitoring**: Prometheus + Grafana
3. **Enable Notifications**: Slack/Email alerts
4. **Set up Webhooks**: GitHub → Jenkins auto-trigger
5. **Implement Blue-Green Deployment**: Zero-downtime updates

---

## 📚 Additional Resources

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [SonarQube Guide](https://docs.sonarqube.org/)
- [ArgoCD Setup](./hybrid-cloud/README.md)
- [Troubleshooting Guide](./TROUBLESHOOTING.md)

---

**🎉 Congratulations!** Your hybrid cloud CI/CD pipeline is now fully operational!
