#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Update package list and install dependencies
echo "Updating package list and installing dependencies..."
sudo apt-get update
sudo apt-get install -y curl gnupg lsb-release wget

# Check if GPU is available
echo "Checking GPU availability..."
GPU_AVAILABLE=false
if command -v nvidia-smi &> /dev/null
then
    echo "GPU detected. NVIDIA driver is installed."
    GPU_AVAILABLE=true
else
    echo "No GPU detected or NVIDIA driver not installed."
fi

# Prompt user for unique service ID
read -p "Enter a unique number for this service instance: " SERVICE_ID
SERVICE_NAME="worker_${SERVICE_ID}"

# Allow the specified port through the firewall
# Prompt user for WORKER_PORT
read -p "Enter the port number for WORKER_PORT (default is 5011): " USER_PORT
USER_PORT=${USER_PORT:-5011}

echo "Allowing port $USER_PORT through the firewall..."
sudo ufw allow ${USER_PORT}/tcp
# Create .env file with user-defined WORKER_PORT and SERVICE_NAME
echo "Creating .env file..."
cat <<EOF > .env
WORKER_PORT=$USER_PORT
SERVICE_NAME=$SERVICE_NAME
EOF

# Create docker-compose.yml file
echo "Creating docker-compose.yml..."
if [ "$GPU_AVAILABLE" = true ]; then
    cat <<EOF > docker-compose.yml
version: '3.8'

services:
  $SERVICE_NAME:
    image: admier/brinxai_nodes-worker:latest
    environment:
      - WORKER_PORT=\${WORKER_PORT:-5011}
    ports:
      - "\${WORKER_PORT:-5011}:\${WORKER_PORT:-5011}"
    volumes:
      - ./generated_images:/usr/src/app/generated_images
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - brinxai-network
    deploy:
      resources:
        reservations:
          devices:
            - capabilities: [gpu]
    runtime: nvidia

networks:
  brinxai-network:
    driver: bridge
    name: brinxai-network-${SERVICE_NAME}  # Explicitly set the network name
EOF
else
    cat <<EOF > docker-compose.yml
version: '3.8'

services:
  $SERVICE_NAME:
    image: admier/brinxai_nodes-worker:latest
    environment:
      - WORKER_PORT=\${WORKER_PORT:-5011}
    ports:
      - "\${WORKER_PORT:-5011}:\${WORKER_PORT:-5011}"
    volumes:
      - ./generated_images:/usr/src/app/generated_images
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - brinxai-network

networks:
  brinxai-network:
    driver: bridge
    name: brinxai-network-${SERVICE_NAME}  # Explicitly set the network name
EOF
fi

# Start Docker containers using docker compose
echo "Starting Docker containers..."
docker compose up -d

echo "Installation and setup completed successfully."
