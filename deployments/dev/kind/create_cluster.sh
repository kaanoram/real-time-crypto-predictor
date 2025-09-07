#!/bin/bash
set -euo pipefail

# Settings (override via env):
# - CLUSTER_NAME: name of the kind cluster
# - USE_CUSTOM_NETWORK: set to 1 to use a custom Docker network
# - DOCKER_NETWORK_NAME: name of the Docker network when custom is enabled
# - DOCKER_NETWORK_SUBNET: subnet for the custom Docker network
# - KIND_WAIT: how long kind waits for the control plane
# - KIND_RETAIN: set to 1 to keep the node container on failure for debugging

CLUSTER_NAME=${CLUSTER_NAME:-rwml-34fa}
USE_CUSTOM_NETWORK=${USE_CUSTOM_NETWORK:-0}
DOCKER_NETWORK_NAME=${DOCKER_NETWORK_NAME:-${CLUSTER_NAME}-network}
# Use a private range by default to avoid conflicts
DOCKER_NETWORK_SUBNET=${DOCKER_NETWORK_SUBNET:-172.18.0.0/16}
KIND_WAIT=${KIND_WAIT:-5m}
KIND_RETAIN=${KIND_RETAIN:-0}

KIND_EXTRA_ARGS=("--wait" "${KIND_WAIT}")
if [[ "${KIND_RETAIN}" == "1" ]]; then
  KIND_EXTRA_ARGS+=("--retain" "-v" "1")
fi

echo "Deleting the cluster..."
kind delete cluster --name "${CLUSTER_NAME}" || true

if [[ "${USE_CUSTOM_NETWORK}" == "1" ]]; then
  echo "Deleting the docker network..."
  docker network rm "${DOCKER_NETWORK_NAME}" || true

  echo "Creating the docker network..."
  docker network create --subnet "${DOCKER_NETWORK_SUBNET}" "${DOCKER_NETWORK_NAME}"

  echo "Creating the cluster (custom network)..."
  KIND_EXPERIMENTAL_DOCKER_NETWORK="${DOCKER_NETWORK_NAME}" \
    kind create cluster --name "${CLUSTER_NAME}" --config ./kind-with-portmapping.yaml "${KIND_EXTRA_ARGS[@]}" || {
      echo "Kind cluster creation failed. Exporting logs..." >&2
      kind export logs --name "${CLUSTER_NAME}" "./kind-logs-${CLUSTER_NAME}-$(date +%s)" || true
      exit 1
    }
else
  echo "Creating the cluster (default network)..."
  kind create cluster --name "${CLUSTER_NAME}" --config ./kind-with-portmapping.yaml "${KIND_EXTRA_ARGS[@]}" || {
    echo "Kind cluster creation failed. Exporting logs..." >&2
    kind export logs --name "${CLUSTER_NAME}" "./kind-logs-${CLUSTER_NAME}-$(date +%s)" || true
    exit 1
  }
fi

echo "Waiting for nodes to be Ready..."
kubectl wait node --for=condition=Ready --all --timeout=300s

# 5. Install default dynamic storage (local-path)
echo "Installing storage..."
chmod +x ./install_storage.sh
./install_storage.sh

# 6. Install Kafka
echo "Installing Kafka..."
chmod +x ./install_kafka.sh
./install_kafka.sh

# 7. Install Kafka UI
echo "Installing Kafka UI..."
chmod +x ./install_kafka_ui.sh
./install_kafka_ui.sh

# 8. Install RisingWave
echo "Installing RisingWave..."
chmod 755 ./install_risingwave.sh
./install_risingwave.sh

# 9. Install Grafana
echo "Installing Grafana..."
chmod +x ./install_grafana.sh
./install_grafana.sh

# 10. Install Metabase
echo "Installing Metabase (Grafana Alternative)..."
chmod +x ./install_metabase.sh
./install_metabase.sh
