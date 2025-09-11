# Trades Service

Ingests cryptocurrency trades from Kraken and publishes them to Kafka as JSON events using Quix Streams.

## Overview
- Source options: live via Kraken WebSocket, or historical via Kraken REST.
- Output: JSON `Trade` messages to a Kafka topic.
- Transport: [quixstreams] producer with JSON serialization.

## Trade Schema
Produced messages conform to the following structure:
```
{
  "product_id": "BTC/USD",
  "price": 60000.5,
  "quantity": 0.01,
  "timestamp": "2025-04-24T11:35:42.856851Z",
  "timestamp_ms": 1713964542856
}
```

## Requirements
- Python 3.12+
- Kafka broker reachable from the service
- Recommended: [uv](https://docs.astral.sh/uv/) for running in this repo

Dependencies are resolved at the workspace root (`pyproject.toml`), including `quixstreams`, `loguru`, `requests`, and `websocket-client`.

## Configuration
Configuration is loaded via environment variables (and optionally `services/trades/settings.env`).

Required:
- `KAFKA_BROKER_ADDRESS`: Kafka bootstrap address (e.g., `localhost:31234`, `kafka:9092`).
- `KAFKA_TOPIC_NAME`: Kafka topic to publish trades (e.g., `trades`).

Optional:
- `LIVE_OR_HISTORICAL`: `live` (default) for WebSocket streaming, or `historical` for REST backfill.
- `LAST_N_DAYS`: Number of days to look back when `historical` (default `30`).
- `PRODUCT_IDS`: JSON list of pairs if you want to override defaults (e.g., `"[\"ETH/EUR\", \"BTC/USD\"]"`). Defaults in code include: `ETH/EUR`, `BTC/USD`, `BTC/EUR`, `ETH/USD`, `SOL/USD`, `SOL/EUR`, `XRP/USD`, `XRP/EUR`.

Notes:
- The code reads an env file at `services/trades/.env` if present, but plain environment variables work equally well.
- Ensure the variable name is `KAFKA_TOPIC_NAME` (some older manifests may use `KAFKA_TOPIC`).

Example local env file (`services/trades/settings.env`):
```
KAFKA_BROKER_ADDRESS=localhost:31234
KAFKA_TOPIC_NAME=trades
LIVE_OR_HISTORICAL=live
# Optional overrides
# PRODUCT_IDS=["ETH/EUR","BTC/USD"]
# LAST_N_DAYS=7
```

An example `services/trades/settings.env` is also provided for convenience with similar values.

## Run Locally
Using uv (recommended in this repo):
```
make dev service=trades
```
or directly:
```
uv run services/trades/src/trades/main.py
```

Without uv (if you prefer plain Python):
```
python -m venv .venv
. .venv/bin/activate
python -m pip install -e .
python services/trades/src/trades/main.py
```

Prerequisites:
- Kafka is running and reachable at `KAFKA_BROKER_ADDRESS`.
- The `KAFKA_TOPIC_NAME` exists or your broker is configured to auto-create topics. Quix Streams will serialize values as JSON.

## Docker
Build the image:
```
docker build -t trades:dev -f docker/trades.Dockerfile .
```

Run the container (using the sample env file):
```
docker run --rm \
  --env-file services/trades/settings.env \
  trades:dev
```

You can also use the helper script to build (and push for prod) or load into kind for dev:
```
# dev: builds local image and loads into kind cluster named rwml-34fa
make build-and-push image=trades env=dev

# prod: builds and pushes to GHCR with a timestamped tag
make build-and-push image=trades env=prod
```

## Kafka Setup
- Recommended (kind + Strimzi):
  - Create cluster: `deployments/dev/kind/create_cluster.sh`
  - Install storage: `deployments/dev/kind/install_storage.sh`
  - Install Kafka: `deployments/dev/kind/install_kafka.sh`
  - External broker NodePort is configured as `127.0.0.1:31234` (see `deployments/dev/kind/manifests/kafka-e11b.yaml`). Set `KAFKA_BROKER_ADDRESS=127.0.0.1:31234`.
  - Quick test with kcat:
    - Produce: `echo '{"k":"v"}' | kcat -b 127.0.0.1:31234 -P -t trades`
    - Consume: `kcat -b 127.0.0.1:31234 -C -t trades -o -1 -q`
- Alternative (single container): run Redpanda locally and use `KAFKA_BROKER_ADDRESS=127.0.0.1:9092`.

## Kubernetes (dev)
Deploy to the dev cluster using the provided manifest and script:
```
make deploy service=trades env=dev
```

The manifest is at `deployments/dev/trades/trades-d.yaml`. Ensure environment variables match the names above, in particular `KAFKA_TOPIC_NAME`.

### Kafka UI (port-forward)
Kafka UI is deployed as a ClusterIP service in the `kafka` namespace. Port-forward it to access from your machine:
```
kubectl -n kafka port-forward svc/kafka-ui 8080:8080
```
Then open http://localhost:8080. If local port 8080 is busy, use a different local port (e.g., 8081:8080) and open http://localhost:8081. Keep the terminal running while you browse.

## Source Selection
- `live` (default): Uses Kraken WebSocket (`wss://ws.kraken.com/v2`). Runs continuously and publishes trades as they arrive.
- `historical`: Uses Kraken REST (`/0/public/Trades`). Fetches from `LAST_N_DAYS` back up to “now” and then exits.

## Logging
Uses `loguru`. During production, you’ll see entries like:
```
Trade {"product_id": "BTC/USD", ...} pushed to Kafka
```

## Troubleshooting
- No messages produced: verify `KAFKA_BROKER_ADDRESS` is reachable and topic exists.
- REST errors (SSL or parsing): the service logs and retries; ensure network access to Kraken and correct pair symbols.
- Only heartbeat messages in live mode: the service ignores heartbeats; trades will appear as executed on the exchange.
- Env var mismatch: use `KAFKA_TOPIC_NAME` rather than `KAFKA_TOPIC`.

## Development
- Lint/format: `make lint`
- Relevant code:
  - Config: `services/trades/src/trades/config.py`
  - Entry: `services/trades/src/trades/main.py`
  - Kraken WebSocket: `services/trades/src/trades/kraken_websocket_api.py`
  - Kraken REST: `services/trades/src/trades/kraken_rest_api.py`
  - Model: `services/trades/src/trades/trade.py`
