#!/bin/bash

echo "🛑 Stopping Port Forwarding..."
pkill -f "kubectl port-forward"

echo "🗑️ Uninstalling Crawler Microservices..."
helm uninstall crawler-apps -n crawler-system || true

echo "🗑️ Uninstalling External Parser..."
helm uninstall external-parser -n external-services || true

echo "🗑️ Uninstalling Infrastructure (Postgres, Redis, Kafka)..."
helm uninstall crawler-infra -n crawler-system || true

echo "🧹 Cleaning up Persistent Volumes..."
kubectl delete pvc --all -n crawler-system || true

echo "✅ All Crawler Kubernetes resources have been terminated locally."
