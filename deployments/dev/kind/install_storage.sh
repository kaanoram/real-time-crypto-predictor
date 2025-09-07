#!/bin/bash
set -euo pipefail

echo "Installing local-path-provisioner (dynamic storage class)..."
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml

echo "Waiting for local-path-provisioner to be Ready..."
kubectl -n local-path-storage rollout status deploy/local-path-provisioner --timeout=180s

echo "Setting 'local-path' as the default StorageClass (idempotent)..."
kubectl annotate storageclass local-path storageclass.kubernetes.io/is-default-class="true" --overwrite || true

echo "Storage ready."
