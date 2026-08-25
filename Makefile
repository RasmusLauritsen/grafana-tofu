.DEFAULT_GOAL := help
.PHONY: help start wait gcx init apply tokens up stop down reset clean restart

help: ## Show available commands
	@printf 'Usage: make <command>\n\nCommands:\n'
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

start: ## Start the Grafana container
	docker compose up -d

wait: ## Wait until Grafana is healthy
	@printf 'Waiting for Grafana'
	@until curl -fsS http://localhost:3000/api/health >/dev/null 2>&1; do printf '.'; sleep 2; done
	@printf '\nGrafana is ready.\n'

gcx: wait ## Configure and verify the gcx local context
	./scripts/bootstrap-gcx.sh

init: ## Initialize OpenTofu and providers
	tofu init

apply: wait init ## Apply OpenTofu resources and write team tokens
	tofu apply -auto-approve
	./scripts/write-tokens.sh

tokens: ## Regenerate tokens.md from OpenTofu state
	./scripts/write-tokens.sh

up: start gcx apply ## Start and provision the complete local stack

stop: ## Stop Grafana while preserving its container and volume
	docker compose stop

down: ## Remove the Grafana container while preserving its volume
	docker compose down

reset: ## Delete the container, volume, OpenTofu state, and tokens
	docker compose down -v
	rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.* tokens.md

clean: reset ## Alias for reset

restart: stop up ## Stop and provision the complete stack again
