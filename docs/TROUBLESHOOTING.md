# 🚨 Troubleshooting Guide

Common issues and their solutions for the Hybrid Cloud CI/CD Pipeline.

---

## 🐳 Docker & Container Issues

### Issue: Jenkins Container Won't Start

**Symptoms:**
```
Error: cannot start container
```

**Solutions:**

1. **Check Docker is running:**
```bash
docker ps
```

2. **Check port conflicts:**
```bash
lsof -i :8080
lsof -i :9000
```

3. **Reset Docker environment:**
```bash
docker-compose down -v
docker-compose up -d
```

4. **Check logs:**
```bash
docker logs jenkins-hybrid-cloud
```

---

### Issue: Docker Socket Permission Denied

**Symptoms:**
```
Permission denied while trying to connect to Docker daemon socket
```

**Solutions:**

```bash
# On Linux
sudo chmod 666 /var/run/docker.sock

# On Mac (Docker Desktop)
# Ensure Docker Desktop is running
# Restart Docker Desktop

# Verify
docker ps
```

---

## 🔐 Authentication & Credentials Issues

### Issue: AWS ECR Login Fails

**Symptoms:**
```
Error saving credentials: error storing credentials
```

**Solutions:**

1. **Verify AWS credentials:**
```bash
aws sts get-caller-identity
```

2. **Re-configure AWS CLI:**
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter region: ap-southeast-1
```

3. **Update Jenkins credentials:**
- Go to Jenkins → Manage Credentials
- Update `aws-access-key-id` and `aws-secret-access-key`

4. **Manual ECR login test:**
```bash
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin 257394468168.dkr.ecr.ap-southeast-1.amazonaws.com
```

---

### Issue: Harbor Registry Authentication Failed

**Symptoms:**
```
unauthorized: authentication required
```

**Solutions:**

1. **Verify Harbor is accessible:**
```bash
curl -k https://harbor.example.com/api/v2.0/health
```

2. **Test manual login:**
```bash
docker login harbor.example.com -u admin
```

3. **Update Jenkins credentials:**
- Verify `harbor-credentials` in Jenkins
- Ensure username/password are correct

4. **Check Harbor security:**
- If using self-signed certificate, add `--insecure-registry` to Docker daemon

---

### Issue: GitHub Authentication Failed

**Symptoms:**
```
Permission denied (publickey)
remote: Invalid username or password
```

**Solutions:**

1. **Verify Personal Access Token:**
- GitHub → Settings → Developer settings → Personal access tokens
- Ensure token has `repo` scope
- Generate new token if needed

2. **Update Jenkins credential:**
```
Jenkins → Manage Credentials → github-pat → Update Secret
```

3. **Test Git access:**
```bash
git ls-remote https://YOUR_TOKEN@github.com/NgHVu/dacn-config.git
```

---

## ⚙️ SonarQube Issues

### Issue: SonarQube Server Unreachable

**Symptoms:**
```
Unable to reach SonarQube server at http://localhost:9000
```

**Solutions:**

1. **Check SonarQube status:**
```bash
docker-compose ps sonarqube
docker logs sonarqube-local
```

2. **Wait for SonarQube to fully start:**
```bash
# SonarQube can take 2-3 minutes to start
# Watch logs
docker logs sonarqube-local -f
```

3. **Verify network connectivity:**
```bash
docker exec jenkins-hybrid-cloud curl http://sonarqube:9000
```

4. **Update SonarQube configuration in Jenkins:**
- Jenkins → Manage Jenkins → Configure System
- SonarQube servers → Server URL should be `http://sonarqube:9000`

---

### Issue: SonarQube Analysis Failed

**Symptoms:**
```
ERROR: Error during SonarQube Scanner execution
```

**Solutions:**

1. **Check SonarQube token:**
- Generate new token in SonarQube UI
- Update Jenkins credential `sonar-token`

2. **Verify project exists in SonarQube:**
- SonarQube → Projects
- If not exists, let Jenkins create it automatically

3. **Check Maven/npm configuration:**
```bash
# For backend services
cd services/users
mvn sonar:sonar -Dsonar.host.url=http://localhost:9000 -Dsonar.token=YOUR_TOKEN

# For frontend
cd services/frontend
npm run sonar
```

---

## 🏗️ Build & Deployment Issues

### Issue: Maven Build Fails

**Symptoms:**
```
Failed to execute goal org.apache.maven.plugins:maven-compiler-plugin
```

**Solutions:**

1. **Check Java version:**
```dockerfile
# Dockerfile should use JDK 21
FROM maven:3.9-eclipse-temurin-21 AS builder
```

2. **Clean and rebuild:**
```bash
cd services/users
mvn clean package -DskipTests
```

3. **Check dependencies:**
```bash
mvn dependency:tree
```

---

### Issue: Docker Build Fails

**Symptoms:**
```
ERROR: failed to solve: process "..." did not complete successfully
```

**Solutions:**

1. **Check Dockerfile syntax:**
```bash
docker build -t test-build ./services/users
```

2. **Clean Docker build cache:**
```bash
docker builder prune -a
```

3. **Check disk space:**
```bash
df -h
docker system df
```

4. **Increase Docker resources:**
- Docker Desktop → Preferences → Resources
- Increase Memory to 4GB+
- Increase Disk to 60GB+

---

### Issue: Image Push Fails

**Symptoms:**
```
denied: requested access to the resource is denied
```

**Solutions:**

1. **For ECR:**
```bash
# Ensure repository exists
aws ecr describe-repositories --repository-names foodhub-users --region ap-southeast-1

# Create if not exists
aws ecr create-repository --repository-name foodhub-users --region ap-southeast-1
```

2. **For Harbor:**
```bash
# Ensure project exists
curl -u admin:password http://harbor.example.com/api/v2.0/projects

# Create if not exists
curl -X POST -u admin:password \
  -H "Content-Type: application/json" \
  http://harbor.example.com/api/v2.0/projects \
  -d '{"project_name": "foodhub", "public": false}'
```

---

## 📝 GitOps Issues

### Issue: GitOps Repository Update Fails

**Symptoms:**
```
fatal: could not read Username for 'https://github.com'
```

**Solutions:**

1. **Verify GitOps repo exists:**
```bash
git ls-remote https://github.com/NgHVu/dacn-config.git
```

2. **Check Jenkins credential:**
- Ensure `github-pat` credential is configured
- Test with new PAT if needed

3. **Verify Jenkinsfile GitOps function:**
```groovy
// Line 467-488 in Jenkinsfile.hybrid-cloud
// Ensure GITOPS_CRED_ID matches your credential ID
```

---

### Issue: Values.yaml Not Found

**Symptoms:**
```
Warning: services/users/aws/values.yaml not found
```

**Solutions:**

1. **Create GitOps structure:**
```bash
cd /path/to/dacn-config
mkdir -p services/users/{aws,openstack}
touch services/users/aws/values.yaml
touch services/users/openstack/values.yaml
```

2. **Initialize values.yaml:**
```bash
cat > services/users/aws/values.yaml << EOF
image:
  repository: 257394468168.dkr.ecr.ap-southeast-1.amazonaws.com/foodhub-users
  tag: latest
  pullPolicy: Always
EOF
```

3. **Commit and push:**
```bash
git add services/
git commit -m "Add values.yaml files"
git push origin main
```

---

## 🔍 Trivy Security Scan Issues

### Issue: Trivy Database Download Fails

**Symptoms:**
```
FATAL: failed to download vulnerability DB
```

**Solutions:**

1. **Check internet connectivity:**
```bash
docker exec jenkins-hybrid-cloud curl -I https://ghcr.io
```

2. **Clear Trivy cache:**
```bash
docker exec jenkins-hybrid-cloud rm -rf /var/lib/jenkins/.trivy-cache
```

3. **Manual database download:**
```bash
docker exec jenkins-hybrid-cloud trivy image --download-db-only
```

---

## 🌐 Network Issues

### Issue: Can't Connect Between Containers

**Symptoms:**
```
Could not resolve host: sonarqube
```

**Solutions:**

1. **Check Docker network:**
```bash
docker network ls
docker network inspect devsecops-hybrid-cloud_devops-network
```

2. **Verify containers are on same network:**
```bash
docker inspect jenkins-hybrid-cloud | grep NetworkMode
docker inspect sonarqube-local | grep NetworkMode
```

3. **Recreate network:**
```bash
docker-compose down
docker-compose up -d
```

---

## 🔧 Pipeline Execution Issues

### Issue: Pipeline Stuck or Hanging

**Symptoms:**
- Build runs for hours without progress
- No logs being generated

**Solutions:**

1. **Check console output:**
- Click on build number → Console Output

2. **Check Jenkins system resources:**
```bash
docker stats jenkins-hybrid-cloud
```

3. **Restart Jenkins:**
```bash
docker-compose restart jenkins
```

4. **Abort and retry:**
- Abort the build
- Review recent changes
- Trigger new build

---

### Issue: Parallel Stages Fail

**Symptoms:**
```
ERROR: script returned exit code 137
```

**Solutions:**

1. **Increase Docker memory:**
- Docker Desktop → Resources → Memory → 6GB+

2. **Reduce parallelism:**
```groovy
// In Jenkinsfile, comment out some parallel stages
// Test one service at a time
```

3. **Check disk space:**
```bash
docker system prune -a
```

---

## 🎯 Quick Diagnostic Commands

### Check All Container Status
```bash
docker-compose ps
docker ps -a
```

### View All Logs
```bash
docker-compose logs -f
```

### Check Jenkins Health
```bash
curl http://localhost:8080/login
```

### Check SonarQube Health
```bash
curl http://localhost:9000/api/system/health
```

### Verify Docker Resources
```bash
docker system df
docker stats
```

### Clean Everything (⚠️ Nuclear option)
```bash
docker-compose down -v
docker system prune -a --volumes
rm -rf ~/.jenkins_home
docker-compose up -d
```

---

## 📞 Getting Help

If none of these solutions work:

1. **Check logs thoroughly:**
```bash
docker logs jenkins-hybrid-cloud > jenkins.log
docker logs sonarqube-local > sonarqube.log
```

2. **Review environment:**
```bash
cat .env
docker-compose config
```

3. **GitHub Issues:**
- Create an issue with logs and error details
- Include your setup (OS, Docker version, etc.)

4. **Stack Overflow:**
- Tag: `jenkins`, `docker-compose`, `devsecops`

---

**💡 Pro Tip:** Most issues are related to credentials or network connectivity. Always start by verifying these first!
