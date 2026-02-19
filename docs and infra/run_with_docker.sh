#!/bin/bash

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo "📄 Loading environment variables from .env..."
else
    echo "⚠️  .env file not found. Using defaults."
fi

echo "🚀 Starting Infrastructure (Kafka, Postgres, Redis)..."
docker-compose -f docker-compose.yml up -d

echo "⏳ Waiting for infrastructure to stabilize (15 seconds)..."
sleep 15

echo "🚀 Starting Crawler Microservices..."
docker-compose -f docker-compose.apps.yml up -d

echo "⏳ Waiting for apps to stabilize (15 seconds)..."
sleep 15

docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo "🎉 Entire system is up!"
echo "Monitor Kafka: http://localhost:9000"
echo "Monitor DB: http://localhost:8088"
echo "Monitor Logs: docker-compose -f docker-compose.yml -f docker-compose.apps.yml logs -f"
