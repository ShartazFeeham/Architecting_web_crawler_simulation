#!/bin/bash

# Define ports used by microservices
PORTS=(8081 8082 8083 8084 8085)

echo "🛑 Stopping Crawler Microservices..."

# 1. Stop local microservices
echo "🏗️  Stopping local microservices..."
pkill -f 'spring-boot:run' && echo " ✅ pkill spring-boot:run success" || echo " ⚠️  No spring-boot:run processes found"
pkill -f 'simulation.crawler' && echo " ✅ pkill simulation.crawler success" || echo " ⚠️  No simulation.crawler processes found"

# 2. Force terminate ports if still active
for port in "${PORTS[@]}"; do
    PID=$(lsof -t -i :$port)
    if [ -n "$PID" ]; then
        echo " 🔥 Port $port is still active (PID: $PID). Terminating..."
        kill -9 $PID && echo " ✅ Port $port terminated." || echo " ❌ Failed to terminate port $port."
    else
        echo " ✅ Port $port is clear."
    fi
done

echo "🏁 ✅ Microservices completely stopped. (Docker infrastructure remains untouched)"
