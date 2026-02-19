#!/bin/bash

# Configuration
SERVICES=("url.discovery" "processor" "fetcher" "parser" "sensor")
IMAGE_PREFIX="crawler"

echo "🧹 Cleaning up existing images..."
for service in "${SERVICES[@]}"; do
    IMAGE_NAME="${IMAGE_PREFIX}-${service//./-}"
    echo "Deleting image: $IMAGE_NAME"
    docker rmi -f "$IMAGE_NAME" 2>/dev/null
done

echo "🚀 Building optimized images (Host Architecture)..."
echo "Note: To build for multiple platforms for a registry, use: "
echo "docker buildx build --platform linux/amd64,linux/arm64 -t username/repo:tag --push ."
echo "----------------------------------------"

for service in "${SERVICES[@]}"; do
    IMAGE_NAME="${IMAGE_PREFIX}-${service//./-}"
    echo "🏗️  Building $IMAGE_NAME..."
    
    # Building for current host architecture to allow local loading (--load)
    # This ensures it works on your Mac and can be verified immediately.
    docker build -t "$IMAGE_NAME" "../$service"
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully built $IMAGE_NAME"
    else
        echo "❌ Failed to build $IMAGE_NAME"
        exit 1
    fi
done

echo ""
echo "🎉 All images built successfully!"
docker images | grep "$IMAGE_PREFIX"
