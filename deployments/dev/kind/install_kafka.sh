#!/bin/bash
set -euo pipefail

# Ensure namespace exists
kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -

# Install or update Strimzi operator (idempotent)
kubectl apply -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka

# Apply Kafka CRs
kubectl apply -f manifests/kafka-e11b.yaml