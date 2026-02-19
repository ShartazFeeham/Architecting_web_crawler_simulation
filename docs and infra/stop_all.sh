#!/bin/bash

echo "🛑 Stopping all microservices..."
pkill -f 'spring-boot:run'
pkill -f 'simulation.crawler'

echo "🐳 Stopping all containers (Infra & Apps)..."
docker-compose -f docker-compose.yml -f docker-compose.apps.yml down

echo "✅ System stopped."
