#!/bin/bash
set -euo pipefail

NAMESPACE=${NAMESPACE:-risingwave}

echo "Creating namespace '${NAMESPACE}' if it doesn't exist..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "Adding Helm repo for RisingWave..."
helm repo add risingwavelabs https://risingwavelabs.github.io/helm-charts || true
helm repo update

echo "Installing RisingWave (includes PostgreSQL + MinIO via tags)..."
helm upgrade --install risingwave risingwavelabs/risingwave \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --values manifests/risingwave-values.yaml \
  --wait \
  --timeout 20m