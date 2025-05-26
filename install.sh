#!/bin/bash

set -e

# Configurable values
SECRET=${1:-$(head -c 16 /dev/urandom | xxd -p)}
DOCKER_COMPOSE_FILE="docker-compose.yml"

/usr/sbin/ufw allow 443

# Colors
GREEN="\e[32m"
RED="\e[31m"
NC="\e[0m"

echo -e "${GREEN}>>> Checking Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not found. Installing Docker...${NC}"
    sudo apt update && sudo apt install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo systemctl enable docker
    sudo systemctl start docker

    echo -e "${GREEN}Docker installed successfully.${NC}"
else
    echo -e "${GREEN}Docker is already installed.${NC}"
fi

echo -e "${GREEN}>>> Checking Docker Compose plugin...${NC}"
if ! docker compose version &> /dev/null; then
    echo -e "${RED}Docker Compose plugin not found. Installing...${NC}"
    sudo apt install -y docker-compose-plugin
    echo -e "${GREEN}Docker Compose plugin installed.${NC}"
else
    echo -e "${GREEN}Docker Compose plugin is already installed.${NC}"
fi

echo -e "${GREEN}>>> Creating docker-compose.yml...${NC}"
cat > "$DOCKER_COMPOSE_FILE" <<EOF
services:
  mtproto-proxy:
    image: telegrammessenger/proxy:latest
    container_name: mtproto-proxy
    ports:
      - "443:443"
    environment:
      - SECRET=${SECRET}
    restart: always
EOF

echo -e "${GREEN}>>> Starting MTProto Proxy container...${NC}"
docker compose up -d

echo -e "${GREEN}>>> Waiting 30 seconds for the proxy to start...${NC}"
sleep 30

echo -e "${GREEN}>>> Fetching proxy server information...${NC}"
echo -e "${GREEN}>>> YOUR PROXY...${NC}"
docker compose logs | grep -i "proxy.*server" || echo -e "${RED}❌ Could not find proxy server info in logs.${NC}"
