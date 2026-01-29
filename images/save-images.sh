#!/bin/bash

echo "=========================================="
echo "Start saving monitoring system images..."
echo "=========================================="

# Switch to script directory
cd "$(dirname "$0")"

echo "1. Pulling images..."
docker pull prom/prometheus:latest
docker pull prom/alertmanager:latest
docker pull grafana/grafana:latest

echo "2. Saving images to current directory..."
echo "Saving prometheus..."
docker save -o prometheus.tar prom/prometheus:latest

echo "Saving alertmanager..."
docker save -o alertmanager.tar prom/alertmanager:latest

echo "Saving grafana..."
docker save -o grafana.tar grafana/grafana:latest

echo "=========================================="
echo "All images saved successfully!"
echo "Location: $(pwd)"
echo "=========================================="
