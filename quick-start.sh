#!/bin/bash
# Quick Start Script for CI/CD Pipeline

set -e

echo "==========================================="
echo "🚀 FoodHub Hybrid Cloud CI/CD Pipeline"
echo "   Quick Start Setup"
echo "==========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    echo "📋 Checking prerequisites..."
    
    command -v docker >/dev/null 2>&1 || {
        echo -e "${RED}❌ Docker is not installed${NC}"
        echo "   Please install Docker Desktop: https://www.docker.com/products/docker-desktop"
        exit 1
    }
    echo -e "${GREEN}✅ Docker found${NC}"
    
    command -v docker-compose >/dev/null 2>&1 || command -v docker compose >/dev/null 2>&1 || {
        echo -e "${RED}❌ Docker Compose is not installed${NC}"
        exit 1
    }
    echo -e "${GREEN}✅ Docker Compose found${NC}"
    
    command -v git >/dev/null 2>&1 || {
        echo -e "${RED}❌ Git is not installed${NC}"
        exit 1
    }
    echo -e "${GREEN}✅ Git found${NC}"
    
    echo ""
}

# Setup environment file
setup_env() {
    echo "📝 Setting up environment variables..."
    
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            echo -e "${YELLOW}⚠️  Created .env file from .env.example${NC}"
            echo -e "${YELLOW}⚠️  Please edit .env and fill in your credentials${NC}"
            echo ""
            echo "   Required variables:"
            echo "   - AWS_ACCESS_KEY_ID"
            echo "   - AWS_SECRET_ACCESS_KEY"
            echo "   - GITOPS_TOKEN (GitHub Personal Access Token)"
            echo ""
            read -p "Press Enter after you've updated the .env file..."
        else
            echo -e "${RED}❌ .env.example not found${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ .env file exists${NC}"
    fi
    echo ""
}

# Make scripts executable
setup_scripts() {
    echo "🔧 Making scripts executable..."
    chmod +x scripts/*.sh 2>/dev/null || true
    chmod +x scripts/hybrid-cloud/*.sh 2>/dev/null || true
    echo -e "${GREEN}✅ Scripts are now executable${NC}"
    echo ""
}

# Build and start services
start_services() {
    echo "🐳 Building and starting services..."
    echo "   This may take 5-10 minutes on first run..."
    echo ""
    
    # Build Jenkins image
    echo "📦 Building Jenkins image..."
    docker-compose build jenkins
    
    # Start all services
    echo "🚀 Starting all services..."
    docker-compose up -d
    
    # Wait for services to be ready
    echo ""
    echo "⏳ Waiting for services to start..."
    sleep 10
    
    # Check Jenkins
    JENKINS_READY=0
    for i in {1..30}; do
        if curl -s http://localhost:8080/login > /dev/null 2>&1; then
            JENKINS_READY=1
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    
    if [ $JENKINS_READY -eq 1 ]; then
        echo -e "${GREEN}✅ Jenkins is ready!${NC}"
    else
        echo -e "${YELLOW}⚠️  Jenkins is still starting (this is normal)${NC}"
        echo "   Check status with: docker logs jenkins-hybrid-cloud -f"
    fi
    
    # Check SonarQube
    echo -e "\n⏳ Waiting for SonarQube (can take 2-3 minutes)..."
    SONAR_READY=0
    for i in {1..60}; do
        if curl -s http://localhost:9000/api/system/health 2>/dev/null | grep -q "UP\|GREEN"; then
            SONAR_READY=1
            break
        fi
        echo -n "."
        sleep 3
    done
    echo ""
    
    if [ $SONAR_READY -eq 1 ]; then
        echo -e "${GREEN}✅ SonarQube is ready!${NC}"
    else
        echo -e "${YELLOW}⚠️  SonarQube is still starting${NC}"
        echo "   Check status with: docker logs sonarqube-local -f"
    fi
    echo ""
}

# Display next steps
display_next_steps() {
    echo "==========================================="
    echo "✅ Setup Complete!"
    echo "==========================================="
    echo ""
    echo "🌐 Access URLs:"
    echo "   Jenkins:   http://localhost:8080"
    echo "   SonarQube: http://localhost:9000"
    echo ""
    echo "🔐 Default Credentials:"
    echo "   Jenkins:"
    echo "     Username: admin"
    echo "     Password: admin123"
    echo ""
    echo "   SonarQube:"
    echo "     Username: admin"
    echo "     Password: admin (you'll be prompted to change)"
    echo ""
    echo "📖 Next Steps:"
    echo "   1. Open Jenkins: http://localhost:8080"
    echo "   2. Configure credentials in Jenkins"
    echo "   3. Open SonarQube and generate a token"
    echo "   4. Update .env with SonarQube token"
    echo "   5. Follow the full guide: docs/DEPLOYMENT-GUIDE.md"
    echo ""
    echo "🔍 Useful Commands:"
    echo "   View logs:      docker-compose logs -f"
    echo "   Stop services:  docker-compose down"
    echo "   Restart:        docker-compose restart"
    echo "   Status:         docker-compose ps"
    echo ""
    echo "==========================================="
}

# Main execution
main() {
    check_prerequisites
    setup_env
    setup_scripts
    start_services
    display_next_steps
}

# Run main function
main
