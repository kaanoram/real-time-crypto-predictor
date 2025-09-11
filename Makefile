SHELL := bash
.PHONY: dev build-and-push deploy lint

# Runs the service as a standalone Python app (not Dockerized)
dev:
	uv run services/${service}/src/${service}/main.py

# Builds and pushes the docker image to the given environment
build-and-push:
	bash scripts/build-and-push-image.sh ${image} ${env}

# Deploys a service to the given environment
deploy:
	bash scripts/deploy.sh ${service} ${env}

lint:
	ruff check . --fix
