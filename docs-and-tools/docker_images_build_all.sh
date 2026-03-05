#!/bin/bash

# Load environment variables if .env exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Configuration
SERVICES=("url.discovery" "processor" "fetcher" "parser" "sensor")
DOCKER_USER="${DOCKER_USERNAME:-feeham}" # Default to feeham
IMAGE_PREFIX="crawler"
VERSION="1.0"

echo "🧹 Starting Build & Push process for Crawler images..."
echo "👤 Docker User: $DOCKER_USER"
echo "🔖 Version: $VERSION"
echo ""

for service in "${SERVICES[@]}"; do
    # Convert dots to dashes for image name
    CLEAN_NAME="${service//./-}"
    BASE_NAME="${IMAGE_PREFIX}-${CLEAN_NAME}"
    
    # Fully qualified names for Docker Hub
    TAGGED_IMAGE="${DOCKER_USER}/${BASE_NAME}:${VERSION}"
    LATEST_IMAGE="${DOCKER_USER}/${BASE_NAME}:latest"
    
    echo "🏗️  Service: $service"
    
    # 1. Build the image
    echo "  🚀 Building $TAGGED_IMAGE..."
    docker build -t "$TAGGED_IMAGE" -t "$LATEST_IMAGE" "../$service"
    
    if [ $? -eq 0 ]; then
        echo "  ✅ Successfully built $TAGGED_IMAGE"
        
        # 2. Push to Docker Hub
        echo "  📤 Pushing $TAGGED_IMAGE..."
        docker push "$TAGGED_IMAGE"
        echo "  📤 Pushing $LATEST_IMAGE..."
        docker push "$LATEST_IMAGE"
        echo "  ✅ Successfully pushed $BASE_NAME"
    else
        echo "  ❌ Failed to build $service"
        echo "🛑 process aborted."
        exit 1
    fi
    echo "----------------------------------------"
done

echo ""
echo "🎉 ✅ All images built and pushed successfully!"
echo "📋 List of processed images:"
docker images | grep "$DOCKER_USER/$IMAGE_PREFIX"
echo ""
echo "🚀 Your images are now live at: https://hub.docker.com/u/$DOCKER_USER"
