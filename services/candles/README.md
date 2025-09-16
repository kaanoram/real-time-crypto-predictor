# Candles Service

Aggregates trades into OHLCV candles using Quix Streams and publishes the results to Kafka.

## Overview
- Input: JSON trades from a Kafka topic (default `trades`).
- Windowing: Tumbling windows of `CANDLE_SECONDS` seconds based on message `timestamp_ms`.
- Output: JSON candles to a Kafka topic (default `candles`).
- Transport: [quixstreams] with JSON serialization; logs via `loguru`.

## Message Schemas
### Input trade (from `trades` service)
```
{
  "product_id": "BTC/USD",
  "price": 60000.5,
  "quantity": 0.01,
  "timestamp": "2025-04-24T11:35:42.856851Z",
  "timestamp_ms": 1713964542856
}
```

### Output candle
```
{
  "pair": "BTC/USD",
  "open": 60000.5,
  "high": 60010.0,
  "low": 59990.0,
  "close": 60005.0,
  "volume": 1.23,
  "window_start_ms": 1713964500000,
  "window_end_ms": 1713964560000,
  "candle_seconds": 60
}
```

Notes:
- The service uses the trade's `timestamp_ms` (payload field) as event time via a custom timestamp extractor.
- Candles are emitted with `.current()` enabled, so you will receive intermediate updates for a window as trades arrive, not only the final close.

## Requirements
- Python 3.12+
- Kafka broker reachable from the service
- Recommended: [uv](https://docs.astral.sh/uv/) for running in this repo

Dependencies are resolved at the workspace root (`pyproject.toml`), including `quixstreams` and `loguru`.

## Configuration
Configuration is loaded via environment variables (and optionally `services/candles/settings.env`).

Required:
- `KAFKA_BROKER_ADDRESS`: Kafka bootstrap address (e.g., `localhost:31234`, `kafka:9092`).
- `KAFKA_INPUT_TOPIC`: Kafka topic to read trades (e.g., `trades`).
- `KAFKA_OUTPUT_TOPIC`: Kafka topic to publish candles (e.g., `candles`).
- `KAFKA_CONSUMER_GROUP`: Consumer group id for this service (e.g., `candles_consumer_group`).
- `CANDLE_SECONDS`: Candle duration in seconds (e.g., `60`).

Example local env file (`services/candles/settings.env`):
```
KAFKA_BROKER_ADDRESS=localhost:31234
KAFKA_INPUT_TOPIC=trades
KAFKA_OUTPUT_TOPIC=candles
KAFKA_CONSUMER_GROUP=candles_consumer_group
CANDLE_SECONDS=60
```

## Run Locally
Using uv (recommended in this repo):
```
make dev service=candles
```
or directly:
```
uv run services/candles/src/candles/main.py
```

Prerequisites:
- Kafka is running and reachable at `KAFKA_BROKER_ADDRESS`.
- Input topic (`KAFKA_INPUT_TOPIC`) contains trade messages with the schema above.

## Docker
Build the image:
```
docker build -t candles:dev -f docker/candles.Dockerfile .
```

Run the container (using the sample env file):
```
docker run --rm \
  --env-file services/candles/settings.env \
  candles:dev
```

Helper script for building and pushing:
```
# dev: builds local image and loads into kind cluster named rwml-34fa
make build-and-push image=candles env=dev

# prod: builds and pushes to GHCR with a timestamped tag
make build-and-push image=candles env=prod
```

## Kubernetes
### Dev
Deploy to the dev cluster using the provided manifest and script:
```
make deploy service=candles env=dev
```
Manifest: `deployments/dev/candles/candles-d.yaml` (uses `image: candles:dev` and `imagePullPolicy: Never`).

### Prod
See `deployments/prod/candles/candles.yaml`. Update the image reference as needed after pushing new tags.

## Implementation Notes
- Windowing: `tumbling_window(timedelta(seconds=CANDLE_SECONDS))` with `reduce(init_candle, update_candle)`.
- Event time: custom extractor uses `value['timestamp_ms']` to align windows by event time, not Kafka ingestion time.
- Emission: `.current()` is applied to emit intermediate candle states during the window.
- Code entrypoint: `services/candles/src/candles/main.py`.
- Config: `services/candles/src/candles/config.py` (Pydantic Settings).

## Troubleshooting
- No output messages: verify the input topic has trades, consumer group is unique, and broker address is correct.
- Unexpected window boundaries: ensure trade `timestamp_ms` is in milliseconds and monotonic per event time; check local clock/timezone is not used.
- High update rate: intermediate emissions produce an update on every trade; if you only need final closings, remove or gate `.current()` in the code.

## Development
- Lint/format: `make lint`
- Relevant files:
  - Entry: `services/candles/src/candles/main.py`
  - Config: `services/candles/src/candles/config.py`
  - Dockerfile: `docker/candles.Dockerfile`
  - Dev manifest: `deployments/dev/candles/candles-d.yaml`
  - Prod manifest: `deployments/prod/candles/candles.yaml`

[quixstreams]: https://quix.io/quix-streams/
