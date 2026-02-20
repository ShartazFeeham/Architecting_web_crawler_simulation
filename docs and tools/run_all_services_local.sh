#!/bin/bash

# Configuration
SERVICES=("url.discovery" "processor" "fetcher" "parser" "sensor")
PORTS=(8081 8083 8082 8084 8085)

# Port Mapping
get_port() {
    case $1 in
        "url.discovery") echo "8081" ;;
        "processor") echo "8083" ;;
        "fetcher") echo "8082" ;;
        "parser") echo "8084" ;;
        "sensor") echo "8085" ;;
        *) echo "unknown" ;;
    esac
}

BASE_DIR=$(pwd)/..
LOGS_DIR="$BASE_DIR/logs"
ALL_SUCCESS=true

# Ensure logs directory exists
mkdir -p "$LOGS_DIR"

# Load .env file if it exists
if [ -f .env ]; then
    echo "📄 Loading environment variables from .env..."
    export $(grep -v '^#' .env | xargs)
fi

echo "🛑 Phase 1: Cleaning up existing local services..."
# Always stop existing services before starting
pkill -f 'spring-boot:run' 2>/dev/null
pkill -f 'simulation.crawler' 2>/dev/null

# Force kill ports to ensure they are available
for port in "${PORTS[@]}"; do
    PID=$(lsof -t -i :$port)
    if [ -n "$PID" ]; then
        echo "🔥 Port $port is still active. Terminating..."
        kill -9 $PID 2>/dev/null
    fi
done
sleep 1
echo " ✅ Cleanup complete."

echo -e "\n🏗️ Phase 2: Building All Services (Sequential)..."

# Build phase
for service in "${SERVICES[@]}"; do
    echo "🔨 Building $service..."
    cd "$BASE_DIR/$service" || { echo "❌ Directory $service not found"; ALL_SUCCESS=false; break; }
    
    ./mvnw clean install -DskipTests > "$LOGS_DIR/build_$service.log" 2>&1
    
    if [ $? -eq 0 ]; then
        echo " ✅ $service build successful."
    else
        echo " ❌ $service build failed. Check $LOGS_DIR/build_$service.log"
        ALL_SUCCESS=false
        break
    fi
done

if [ "$ALL_SUCCESS" = false ]; then
    echo " 🛑 Build phase failed. Aborting."
    exit 1
fi

echo -e "\n🚀 Phase 3: Launching Services (Sequential)..."

# Launch phase
for service in "${SERVICES[@]}"; do
    PORT=$(get_port "$service")
    
    cd "$BASE_DIR/$service" || { echo "❌ Directory $service not found"; ALL_SUCCESS=false; continue; }
    
    # Run spring-boot:run in background
    ./mvnw spring-boot:run -Dspring-boot.run.profiles=dev > "$LOGS_DIR/$service.log" 2>&1 &
    
    if [ $? -eq 0 ]; then
        echo " ✅ $service started at port $PORT"
    else
        echo " ❌ Failed to launch $service"
        ALL_SUCCESS=false
    fi
    # Wait a moment for service to start releasing logs
    sleep 2
done

echo ""
if [ "$ALL_SUCCESS" = true ]; then
    echo " 🎉 All services built and started successfully."
else
    echo " 🛑 Some services failed to start. Check logs in $LOGS_DIR"
    exit 1
fi
