#!/bin/bash

# ================================================================= #
# FoodHub Hybrid Cloud - Demo Startup Script
# ================================================================= #

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}🚀 FoodHub Hybrid Cloud - Demo Environment Setup${NC}"
echo -e "${BLUE}=================================================${NC}"

# 1. Prerequisites Check
echo -e "\n${BLUE}Step 1: Checking Prerequisites...${NC}"
command -v docker >/dev/null 2>&1 || { echo -e "${YELLOW}❌ Docker not found${NC}"; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo -e "${YELLOW}❌ Docker Compose not found${NC}"; exit 1; }
echo -e "${GREEN}✅ Docker and Docker Compose are ready${NC}"

# 2. Setup Environment
echo -e "\n${BLUE}Step 2: Preparing Environment...${NC}"
if [ ! -f .env ]; then
    cp .env.example .env
    echo -e "${YELLOW}⚠️  Created .env from template. Please update with your credentials if testing cloud features.${NC}"
else
    echo -e "${GREEN}✅ .env file exists${NC}"
fi

# 3. Start Services
echo -e "\n${BLUE}Step 3: Starting Demo Services...${NC}"
docker-compose -f docker-compose.demo.yml build --parallel
docker-compose -f docker-compose.demo.yml up -d

# 4. Success Message and Access Info
echo -e "\n${BLUE}=================================================${NC}"
echo -e "${GREEN}✅ All services are starting in the background!${NC}"
echo -e "${BLUE}=================================================${NC}"
echo -e "\n${BLUE}🌐 Access your demo at:${NC}"
echo -e "   - Frontend:    ${GREEN}http://localhost:3000${NC}"
echo -e "   - Jenkins:     ${GREEN}http://localhost:8080${NC} (admin/admin123)"
echo -e "   - SonarQube:   ${GREEN}http://localhost:9000${NC} (admin/admin)"
echo -e "   - API Gateway: ${GREEN}http://localhost:8082, 8083, 8084${NC}"
echo -e "\n${BLUE}📊 Monitoring:${NC}"
echo -e "   - View logs:   ${YELLOW}docker-compose -f docker-compose.demo.yml logs -f${NC}"
echo -e "   - Stop demo:   ${YELLOW}docker-compose -f docker-compose.demo.yml down${NC}"
echo -e "${BLUE}=================================================${NC}"
