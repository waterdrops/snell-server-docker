# Local development and pre-push checks
#
# Quick start:
#   make pre-push          # build + test (run before git push)
#   make build SNELL_VERSION=6.0.0b3
#   make run               # start container for manual testing

IMAGE         ?= snell-server
TAG           ?= local
SNELL_VERSION ?= 6.0.0b3
FULL_IMAGE    := $(IMAGE):$(TAG)
PLATFORMS     ?= linux/386,linux/amd64,linux/arm64
TEST_PORT     ?= 8234
TEST_PSK      ?= test12345678901234567890123456789012

DOCKER_BUILD  := docker build --build-arg SNELL_VERSION=$(SNELL_VERSION) -t $(FULL_IMAGE) .
DOCKER_SH     := docker run --rm --entrypoint /bin/sh $(FULL_IMAGE) -c

.PHONY: help pre-push check build test test-binary test-config test-validation \
        test-config-default test-config-ipv6 test-config-listen test-config-mode \
        test-config-full test-config-existing test-validation-mode test-validation-port \
        test-validation-dns test-script scan lint run buildx clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make [target]\n\nTargets:\n"} \
		/^[a-zA-Z0-9_.-]+:.*##/ {printf "  %-22s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

pre-push: check ## Run all checks before pushing code
	@echo "==> Ready to push."

check: build test scan lint ## Build image and run all local checks

build: ## Build Docker image for local platform
	@echo "==> Building $(FULL_IMAGE) (SNELL_VERSION=$(SNELL_VERSION))..."
	$(DOCKER_BUILD)

test: test-binary test-config test-validation ## Run all runtime checks

test-binary: build ## Verify snell-server loads without missing shared libraries
	@echo "==> Checking snell-server dynamic libraries..."
	@$(DOCKER_SH) 'set -eu; \
		CONF=/tmp/snell-binary-test.conf; \
		printf "%s\n" \
			"[snell-server]" \
			"listen = 127.0.0.1:$(TEST_PORT)" \
			"psk = $(TEST_PSK)" \
			"mode = default" \
			> "$$CONF"; \
		out=$$(timeout 2 /app/snell-server -c "$$CONF" 2>&1 || true); \
		echo "$$out" | grep -q "error while loading shared libraries" && { echo "$$out"; exit 1; }; \
		echo "$$out" | grep -q "snell-server v" || { echo "$$out"; exit 1; }; \
		echo "==> [PASS] snell-server binary loads successfully."'

test-config: test-config-default test-config-ipv6 test-config-listen \
	test-config-mode test-config-full test-config-existing ## Verify snell.sh config generation

test-config-default: build ## Default env: listen, dns-ip-preference, mode, tfo
	@echo "==> test: default config generation"
	@$(DOCKER_SH) 'set -eu; \
		CONF=/tmp/snell-test.conf; rm -f "$$CONF"; \
		DRY_RUN=1 PORT=$(TEST_PORT) PSK=$(TEST_PSK) CONF="$$CONF" /app/snell.sh >/dev/null; \
		grep -qxF "listen = 0.0.0.0:$(TEST_PORT)" "$$CONF"; \
		grep -qxF "psk = $(TEST_PSK)" "$$CONF"; \
		grep -qxF "dns-ip-preference = default" "$$CONF"; \
		grep -qxF "mode = default" "$$CONF"; \
		grep -qxF "tfo = true" "$$CONF"; \
		grep -q "^ipv6 =" "$$CONF" && exit 1 || true; \
		echo "==> [PASS] default config"'

test-config-ipv6: build ## IPv6=true: dual-stack listen and ipv6 field
	@echo "==> test: IPv6 dual-stack listen"
	@$(DOCKER_SH) 'set -eu; \
		CONF=/tmp/snell-test.conf; rm -f "$$CONF"; \
		DRY_RUN=1 PORT=$(TEST_PORT) PSK=$(TEST_PSK) IPv6=true CONF="$$CONF" /app/snell.sh >/dev/null; \
		grep -qxF "listen = 0.0.0.0:$(TEST_PORT),[::]:$(TEST_PORT)" "$$CONF"; \
		grep -qxF "ipv6 = true" "$$CONF"; \
		echo "==> [PASS] IPv6 config"'

test-config-listen: build ## Custom LISTEN overrides default listen address
	@echo "==> test: custom LISTEN"
	@$(DOCKER_SH) 'set -eu; \
		CONF=/tmp/snell-test.conf; rm -f "$$CONF"; \
		DRY_RUN=1 PORT=$(TEST_PORT) PSK=$(TEST_PSK) LISTEN=127.0.0.1:7777 CONF="$$CONF" /app/snell.sh >/dev/null; \
		grep -qxF "listen = 127.0.0.1:7777" "$$CONF"; \
		echo "==> [PASS] LISTEN override"'

test-config-mode: build ## MODE=unshaped written to config
	@echo "==> test: MODE=unshaped"
	@$(DOCKER_SH) 'set -eu; \
		CONF=/tmp/snell-test.conf; rm -f "$$CONF"; \
		DRY_RUN=1 PORT=$(TEST_PORT) PSK=$(TEST_PSK) MODE=unshaped CONF="$$CONF" /app/snell.sh >/dev/null; \
		grep -qxF "mode = unshaped" "$$CONF"; \
		echo "==> [PASS] MODE config"'

test-config-full: build ## All optional fields: DNS, MODE, OBFS, OBFS_HOST, TFO
	@echo "==> test: full optional config"
	@$(DOCKER_SH) 'set -eu; \
		CONF=/tmp/snell-test.conf; rm -f "$$CONF"; \
		DRY_RUN=1 PORT=$(TEST_PORT) PSK=$(TEST_PSK) CONF="$$CONF" \
			IPv6=true TFO=false MODE=unsafe-raw DNS_IP_PREFERENCE=prefer-ipv4 \
			OBFS=http OBFS_HOST=gateway.icloud.com /app/snell.sh >/dev/null; \
		grep -qxF "listen = 0.0.0.0:$(TEST_PORT),[::]:$(TEST_PORT)" "$$CONF"; \
		grep -qxF "dns-ip-preference = prefer-ipv4" "$$CONF"; \
		grep -qxF "mode = unsafe-raw" "$$CONF"; \
		grep -qxF "obfs = http" "$$CONF"; \
		grep -qxF "obfs-host = gateway.icloud.com" "$$CONF"; \
		grep -qxF "tfo = false" "$$CONF"; \
		echo "==> [PASS] full config"'

test-config-existing: build ## Existing config file is preserved (no overwrite)
	@echo "==> test: existing config preserved"
	@$(DOCKER_SH) 'set -eu; \
		CONF=/tmp/snell-test.conf; \
		printf "%s\n" \
			"[snell-server]" \
			"listen = 10.0.0.1:6000" \
			"psk = preservedpsk1234567890123456789012" \
			"dns-ip-preference = prefer-ipv6" \
			"mode = unshaped" \
			"tfo = false" \
			> "$$CONF"; \
		DRY_RUN=1 CONF="$$CONF" /app/snell.sh 2>&1 | grep -q "Using existing config"; \
		grep -qxF "listen = 10.0.0.1:6000" "$$CONF"; \
		grep -qxF "mode = unshaped" "$$CONF"; \
		echo "==> [PASS] existing config"'

test-validation: test-validation-mode test-validation-port test-validation-dns ## Verify invalid input is rejected

test-validation-mode: build ## Invalid MODE exits with error
	@echo "==> test: reject invalid MODE"
	@$(DOCKER_SH) 'set -eu; \
		CONF=/tmp/snell-test.conf; rm -f "$$CONF"; \
		if DRY_RUN=1 PORT=$(TEST_PORT) PSK=$(TEST_PSK) MODE=invalid CONF="$$CONF" /app/snell.sh >/dev/null 2>&1; then \
			echo "expected failure for invalid MODE"; exit 1; \
		fi; \
		[ ! -f "$$CONF" ] || ! grep -q "^mode =" "$$CONF"; \
		echo "==> [PASS] invalid MODE rejected"'

test-validation-port: build ## Invalid PORT exits with error
	@echo "==> test: reject invalid PORT"
	@$(DOCKER_SH) 'set -eu; \
		CONF=/tmp/snell-test.conf; rm -f "$$CONF"; \
		if DRY_RUN=1 PORT=80 PSK=$(TEST_PSK) CONF="$$CONF" /app/snell.sh >/dev/null 2>&1; then \
			echo "expected failure for invalid PORT"; exit 1; \
		fi; \
		echo "==> [PASS] invalid PORT rejected"'

test-validation-dns: build ## Invalid DNS_IP_PREFERENCE exits with error
	@echo "==> test: reject invalid DNS_IP_PREFERENCE"
	@$(DOCKER_SH) 'set -eu; \
		CONF=/tmp/snell-test.conf; rm -f "$$CONF"; \
		if DRY_RUN=1 PORT=$(TEST_PORT) PSK=$(TEST_PSK) DNS_IP_PREFERENCE=bad CONF="$$CONF" /app/snell.sh >/dev/null 2>&1; then \
			echo "expected failure for invalid DNS_IP_PREFERENCE"; exit 1; \
		fi; \
		echo "==> [PASS] invalid DNS_IP_PREFERENCE rejected"'

test-script: test-config-full ## Alias: dry-run smoke test with full env (legacy target)

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
	@echo "==> Starting $(FULL_IMAGE) on port $(TEST_PORT)..."
	@docker run --rm -it \
		--stop-timeout 2 \
		-p $(TEST_PORT):$(TEST_PORT) \
		-e PORT=$(TEST_PORT) \
		-e PSK=$(TEST_PSK) \
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
