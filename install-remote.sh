#!/bin/bash

set -e  # Exit on any error

# Configuration
GITHUB_USER="yashwant-cashfree"
GITHUB_REPO="test"
BRANCH="main"
TARGET_DIR="/tmp/deployment"
ZIP_URL="https://github.com/$GITHUB_USER/$GITHUB_REPO/archive/$BRANCH.zip"
DOCKER_COMPOSE_FILE="docker-compose.yml"

echo "Starting deployment on macOS..."

# Install dependencies if not present
if ! command -v unzip &>/dev/null; then
    echo "Unzip not found. Installing via Homebrew..."
    brew install unzip
fi

if ! command -v docker &>/dev/null; then
    echo "Docker not found. Installing via Homebrew..."
    brew install --cask docker
    open -a Docker  # Start Docker app
    sleep 10  # Give Docker some time to start
fi

if ! command -v docker-compose &>/dev/null; then
    echo "Docker Compose not found. Installing..."
    brew install docker-compose
fi

# Ensure target directory is clean
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

echo "Downloading GitHub repository: $ZIP_URL"
curl -L -o "$TARGET_DIR/repo.zip" "$ZIP_URL" || wget -O "$TARGET_DIR/repo.zip" "$ZIP_URL"

echo "Extracting repository..."
unzip -q "$TARGET_DIR/repo.zip" -d "$TARGET_DIR"

# Find the extracted folder (GitHub adds '-branchname' to the folder name)
EXTRACTED_FOLDER=$(find "$TARGET_DIR" -maxdepth 1 -type d -name "$GITHUB_REPO-*")
if [ -z "$EXTRACTED_FOLDER" ]; then
    echo "Error: Failed to find extracted folder."
    exit 1
fi

echo "Moving extracted files to $TARGET_DIR..."
mv "$EXTRACTED_FOLDER"/* "$TARGET_DIR"
rm -rf "$EXTRACTED_FOLDER" "$TARGET_DIR/repo.zip"

# Navigate to the deployment folder
cd "$TARGET_DIR"

# Ensure docker-compose.yml exists
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    echo "Error: $DOCKER_COMPOSE_FILE not found in $TARGET_DIR"
    exit 1
fi

# Run Docker Compose
echo "Starting services with Docker Compose..."
docker-compose up -d

echo "Deployment completed successfully."

# Fetch running services and their mapped ports
echo -e "\n🔗 Access your services at:"
echo "-----------------------------------"

SERVICES=$(grep '^[[:space:]]*[^[:space:]]' "$DOCKER_COMPOSE_FILE" | cut -d: -f1)

echo "✅ Control Panel → http://localhost:8099"
echo "✅ Payments → http://localhost:8049"
echo "✅ Grafana → http://localhost:4000"
echo "✅ Metabase → http://localhost:3000"
echo "✅ Prometheus → http://localhost:9090"


echo "-----------------------------------"
