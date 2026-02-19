#!/bin/bash

# Configuration
SERVICES=("url.discovery" "processor" "fetcher" "parser" "sensor")
BASE_DIR=$(pwd)/..

# Load .env file if it exists
if [ -f .env ]; then
    echo "📄 Loading environment variables from .env..."
    export $(grep -v '^#' .env | xargs)
fi

# Handle Restart
if [ "$1" == "restart" ]; then
    echo "🔄 Restarting system and clearing state..."
    bash stop_all.sh
    docker-compose down -v
fi

# 1. Start Infrastructure
echo "🚀 Starting Infrastructure (Kafka, Postgres, Zookeeper)..."
docker-compose up -d

echo "⏳ Waiting for databases and Kafka to be ready..."
sleep 20

# 2. Start Microservices
for service in "${SERVICES[@]}"; do
    echo "🏗️  Starting $service..."
    cd "$BASE_DIR/$service" || exit
    ./mvnw clean spring-boot:run -Dspring-boot.run.profiles=dev > "$BASE_DIR/logs/$service.log" 2>&1 &
    echo "✅ $service is starting. Logs: logs/$service.log"
done

echo "🎉 All services are starting."
echo "Monitor Kafka: http://localhost:9000"
echo "Monitor DB: http://localhost:8088 (admin@admin.com / admin)"
