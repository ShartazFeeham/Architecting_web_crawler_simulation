#!/bin/bash

echo "🔌 Starting Port Forwarding for local testing..."

# Kills any existing port forwards
pkill -f "kubectl port-forward"

# Forward URL Discovery
kubectl port-forward svc/url-discovery 8081:8081 -n crawler-system > /dev/null 2>&1 &
echo "✅ URL Discovery available on http://localhost:8081"

# Forward Processor
kubectl port-forward svc/processor 8083:8083 -n crawler-system > /dev/null 2>&1 &
echo "✅ Processor available on http://localhost:8083"

echo "Ready! You can now run the test-runner.sh script."
echo "To stop port forwarding later, run: pkill -f \"kubectl port-forward\""
