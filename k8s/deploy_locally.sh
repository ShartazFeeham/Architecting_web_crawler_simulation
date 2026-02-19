#!/bin/bash

echo "☸️  Setting up Kubernetes Environment..."

# 1. Create Namespaces
kubectl apply -f namespaces.yaml

# 2. Deploy Infrastructure
echo "🚀 Deploying Infrastructure (Postgres, Redis, Kafka)..."
helm upgrade --install crawler-infra ./helm/crawler-infra -n crawler-system

# 3. Deploy External World (Parser)
echo "🌍 Deploying External World (Parser)..."
helm upgrade --install external-parser ./helm/external-world/parser -n external-services

# 4. Deploy Crawler Apps
echo "🤖 Deploying Crawler Microservices..."
helm upgrade --install crawler-apps ./helm/apps -n crawler-system

echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=crawler-pg-db -n crawler-system --timeout=120s
kubectl wait --for=condition=ready pod -l app=kafka -n crawler-system --timeout=120s

echo "✅ System deployed to Kubernetes!"
kubectl get pods -n crawler-system
kubectl get pods -n external-services
