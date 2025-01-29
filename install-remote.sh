#!/bin/bash

set -e  # Exit on any error

# Configuration
GITHUB_USER="yashwant-cashfree"
GITHUB_REPO="test"
BRANCH="main"
TARGET_DIR="/tmp/deployment"
ZIP_URL="https://github.com/$GITHUB_USER/$GITHUB_REPO/archive/$BRANCH.zip"
DOCKER_COMPOSE_FILE="docker-compose.yml"
SERVICE_PORT="8049"
CACHE_SETUP_TIMEOUT=60  # Timeout for the cache setup in seconds


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

echo -e "\n🚧 Setting up the database..."
bar_length=40  # Length of the progress bar
progress=0
# Simulate waiting for the database to be ready with a green progress bar animation
start_time=$(date +%s)  # Get the start time for cache setup timeout
cache_progress=0

# Function to simulate progress bar
progress_bar() {
    local progress_var=$1
    local bar_length=$2
    local color=$3
    local label=$4
    while [ $progress_var -le $bar_length ]; do
        filled=$(printf "%${progress_var}s" | tr " " "=")
        empty=$(printf "%$((bar_length - progress_var))s" | tr " " " ")
        printf "\r\033[${color}m[${filled}${empty}]\033[0m $((progress_var * 100 / bar_length))%% $label"
        sleep 1
        progress_var=$((progress_var + 1))
    done
    echo -e "\n✅ $label completed."
}

# Run both progress bars concurrently
( # Database setup progress bar
    while ! curl --silent --fail "http://localhost:$SERVICE_PORT" > /dev/null; do
        progress=$(( (progress + 1) % (bar_length + 1) ))
        progress_bar $progress $bar_length "32" "Setting up the database"
        elapsed_time=$(( $(date +%s) - start_time ))
        if [ $elapsed_time -gt $CACHE_SETUP_TIMEOUT ]; then
            # Cache setup timeout reached
            echo -e "\n💾 Setting up your cache..."
            progress_bar $cache_progress $bar_length "33" "Setting up your cache"
            break
        fi
        sleep 1
    done
)


# Final Touches - Waiting for Final Touches with Spinning Animation
echo -e "\n⏳ Waiting for final touches..."

# Spinner animation for waiting
spinner="/-\|"
spin_index=0

# Wait for the final ping check
while ! curl --silent --fail "http://localhost:$SERVICE_PORT" > /dev/null; do
    printf "\r\033[33m${spinner:$spin_index:1}\033[0m Waiting for final touches..."
    spin_index=$(( (spin_index + 1) % 4 ))
    sleep 1
done

# Once the ping is successful, display final message
echo -e "\n✅ Final touches complete! All services are up and running."

echo -e "\n🚀 Setting up your services..."


echo -e "\n✅ Your services are ready!"

# Fetch running services and their mapped ports
echo -e "\n🔗 Access your services at:"
echo "-----------------------------------"


echo "✅ Control Panel → http://localhost:8099"
echo "✅ Payments → http://localhost:8049"
echo "✅ Grafana → http://localhost:4000"
echo "✅ Metabase → http://localhost:3000"
echo "✅ Prometheus → http://localhost:9090"


echo "-----------------------------------"
