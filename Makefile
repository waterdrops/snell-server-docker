# Local development and pre-push checks
#
# Quick start:
#   make pre-push          # build + test (run before git push)
#   make build SNELL_VERSION=6.0.0b1
#   make run               # start container for manual testing

IMAGE        ?= snell-server
TAG          ?= local
SNELL_VERSION ?= 6.0.0b1
FULL_IMAGE   := $(IMAGE):$(TAG)
PLATFORMS    ?= linux/386,linux/amd64,linux/arm64

DOCKER_BUILD := docker build --build-arg SNELL_VERSION=$(SNELL_VERSION) -t $(FULL_IMAGE) .

.PHONY: help pre-push check build test test-binary test-script scan lint run buildx clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make [target]\n\nTargets:\n"} \
		/^[a-zA-Z0-9_.-]+:.*##/ {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

pre-push: check ## Run all checks before pushing code
	@echo "==> Ready to push."

check: build test scan lint ## Build image and run all local checks

build: ## Build Docker image for local platform
	@echo "==> Building $(FULL_IMAGE) (SNELL_VERSION=$(SNELL_VERSION))..."
	$(DOCKER_BUILD)

test: test-binary test-script ## Run runtime checks

test-binary: build ## Verify snell-server loads without missing shared libraries
	@echo "==> Checking snell-server dynamic libraries..."
	@docker run --rm --entrypoint /bin/sh $(FULL_IMAGE) -c ' \
		out=$$(/app/snell-server -c /dev/null 2>&1 || true); \
		echo "$$out"; \
		echo "$$out" | grep -q "error while loading shared libraries" && exit 1; \
		echo "==> snell-server binary loads successfully."'

test-script: build ## Run snell.sh in dry-run mode
	@echo "==> Running snell.sh dry-run..."
	@docker run --rm \
		-e DRY_RUN=1 \
		-e PORT=8234 \
		-e PSK=test12345678901234567890123456789012 \
		$(FULL_IMAGE)

scan: ## Run Trivy filesystem scan (skipped if trivy is not installed)
	@if command -v trivy >/dev/null 2>&1; then \
		echo "==> Running Trivy scan..."; \
		trivy fs \
			--severity CRITICAL,HIGH \
			--scanners vuln,secret,misconfig \
			--ignore-unfixed \
			--exit-code 1 \
			.; \
	else \
		echo "==> trivy not installed, skipping scan (install: https://aquasecurity.github.io/trivy)."; \
	fi

lint: ## Run shellcheck on snell.sh (skipped if shellcheck is not installed)
	@if command -v shellcheck >/dev/null 2>&1; then \
		echo "==> Running shellcheck..."; \
		shellcheck snell.sh; \
	else \
		echo "==> shellcheck not installed, skipping lint."; \
	fi

run: build ## Run container locally (PORT=8234, fixed PSK for testing)
	@echo "==> Starting $(FULL_IMAGE) on port 8234..."
	@docker run --rm -it \
		--stop-timeout 2 \
		-p 8234:8234 \
		-e PORT=8234 \
		-e PSK=test12345678901234567890123456789012 \
		$(FULL_IMAGE)

buildx: ## Multi-arch build with buildx (load current platform only)
	@echo "==> Building multi-arch image (load local platform)..."
	@docker buildx version >/dev/null 2>&1 || { echo "docker buildx is required"; exit 1; }
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg SNELL_VERSION=$(SNELL_VERSION) \
		-t $(FULL_IMAGE) \
		--load \
		.

clean: ## Remove local test image
	@docker rmi $(FULL_IMAGE) 2>/dev/null || true
	@echo "==> Cleaned $(FULL_IMAGE)"
