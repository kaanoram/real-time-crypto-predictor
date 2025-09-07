#!/bin/bash
set -euo pipefail

# Ensure namespace exists
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Add and refresh Helm repo (idempotent)
helm repo add grafana https://grafana.github.io/helm-charts || true
helm repo update

# Install/upgrade Grafana with a longer timeout to accommodate image pulls and PVC binding
helm upgrade --install grafana grafana/grafana \
  --namespace=monitoring \
  --values manifests/grafana-values.yaml \
  --create-namespace \
  --wait \
  --timeout 15m