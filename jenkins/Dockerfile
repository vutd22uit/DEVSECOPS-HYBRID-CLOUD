# ================================================================= #
# Giai đoạn 1: Base Image & ARGuments
# ================================================================= #
# TỐI ƯU 1: Nâng cấp lên JDK 21 để đồng bộ với môi trường build
FROM jenkins/jenkins:lts-jdk21

# TỐI ƯU 2: Sử dụng ARG để linh hoạt hóa phiên bản
ARG TRIVY_VERSION="0.49.1" # Kiểm tra phiên bản mới nhất tại GitHub của Trivy

# ================================================================= #
# Giai đoạn 2: Cài đặt với quyền Root
# ================================================================= #
USER root

# Cài đặt các công cụ điều phối cốt lõi
# Gộp các lệnh RUN để tối ưu layer
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  git \
  curl \
  unzip \
  ca-certificates \
  gnupg && \
  rm -rf /var/lib/apt/lists/*

# Cài đặt Docker CLI với phiên bản đã chỉ định
RUN install -m 0755 -d /etc/apt/keyrings && \
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
  chmod a+r /etc/apt/keyrings/docker.gpg && \
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null && \
  apt-get update && \
  apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin

# Cài đặt Trivy với phiên bản đã chỉ định
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v${TRIVY_VERSION}

# Cài đặt AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
  unzip awscliv2.zip && \
  ./aws/install && \
  rm -rf awscliv2.zip ./aws

# Cài đặt Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" | \
  tee /etc/apt/sources.list.d/hashicorp.list && \
  apt-get update && apt-get install -y terraform

# Cài đặt kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
  rm kubectl

# Cài đặt Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Cài đặt ArgoCD CLI
RUN curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && \
  install -m 0755 argocd-linux-amd64 /usr/local/bin/argocd && \
  rm argocd-linux-amd64

# ================================================================= #
# Giai đoạn 3: Cài đặt Jenkins Plugins
# ================================================================= #
# Copy danh sách plugins và cài đặt
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# ================================================================= #
# Giai đoạn 4: Cấu hình JCasC (Configuration as Code)
# ================================================================= #
# Copy cấu hình JCasC vào thư mục reference (sẽ được copy vào JENKINS_HOME khi khởi động)
COPY casc.yaml /usr/share/jenkins/ref/casc_configs/casc.yaml

# Thiết lập biến môi trường cho JCasC
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/casc.yaml
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

# ================================================================= #
# Giai đoạn 5: Chuyển về user jenkins
# ================================================================= #
USER jenkins