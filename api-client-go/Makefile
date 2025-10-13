# PacketFence API Client (Go) - Makefile

.PHONY: all build clean test lint fmt help install run-example run-cli run-tests deps

# Variables
BINARY_DIR = bin
CLI_BINARY = $(BINARY_DIR)/pf-api-client
TEST_BINARY = $(BINARY_DIR)/pf-test-suite
EXAMPLE_BINARY = $(BINARY_DIR)/pf-example

# Default target
all: build

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

deps: ## Download and install dependencies
	go mod download
	go mod tidy

build: deps ## Build all binaries
	@echo "Building PacketFence API Client binaries..."
	@mkdir -p $(BINARY_DIR)
	go build -o $(CLI_BINARY) ./cmd/pf-api-client
	go build -o $(TEST_BINARY) ./cmd/pf-test-suite
	@echo "✓ Binaries built successfully in $(BINARY_DIR)/"

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	rm -rf $(BINARY_DIR)
	go clean
	@echo "✓ Clean completed"

fmt: ## Format Go code
	go fmt ./...

lint: ## Run linters
	@if command -v golangci-lint > /dev/null; then \
		golangci-lint run; \
	else \
		echo "golangci-lint not installed, running go vet instead"; \
		go vet ./...; \
	fi

test: ## Run Go tests
	go test -v ./...

# Installation targets
install: build ## Install binaries to $GOPATH/bin
	@echo "Installing binaries to $$GOPATH/bin..."
	cp $(CLI_BINARY) $$GOPATH/bin/
	cp $(TEST_BINARY) $$GOPATH/bin/
	@echo "✓ Installation completed"

# Usage examples
run-example: build ## Run usage examples
	@echo "🚀 Running PacketFence API Client examples..."
	$(CLI_BINARY) --help

connect: build ## Test connection to PacketFence API
	@echo "🔗 Testing connection to PacketFence API..."
	$(CLI_BINARY) connect --url $(URL) --username $(USER) --password $(PASS)

test-basic: build ## Run basic API tests
	@echo "🧪 Running basic API tests..."
	$(CLI_BINARY) test basic --url $(URL) --username $(USER) --password $(PASS)

test-comprehensive: build ## Run comprehensive API tests
	@echo "🧪 Running comprehensive API tests..."
	$(CLI_BINARY) test comprehensive --url $(URL) --username $(USER) --password $(PASS)

test-suite: build ## Run automated test suite
	@echo "🤖 Running automated test suite..."
	$(TEST_BINARY) test-suite --url $(URL) --username $(USER) --password $(PASS)

get-nodes: build ## Get nodes from API
	@echo "📱 Getting nodes from API..."
	$(CLI_BINARY) get nodes --limit 5 --url $(URL) --username $(USER) --password $(PASS)

get-users: build ## Get users from API  
	@echo "👥 Getting users from API..."
	$(CLI_BINARY) get users --limit 5 --url $(URL) --username $(USER) --password $(PASS)

get-status: build ## Get system status
	@echo "⚙️ Getting system status..."
	$(CLI_BINARY) get status --url $(URL) --username $(USER) --password $(PASS)

endpoints: build ## List all available endpoints
	@echo "📋 Listing all available endpoints..."
	$(CLI_BINARY) endpoints

# Quick test with default values
quick-test: build ## Quick test with default localhost values
	@echo "⚡ Quick test with default values..."
	$(CLI_BINARY) test basic --url https://localhost:9999 --username admin --password admin --verify-ssl=false

# Development helpers
dev-build: ## Build in development mode with race detector
	go build -race -o $(CLI_BINARY) ./cmd/pf-api-client
	go build -race -o $(TEST_BINARY) ./cmd/pf-test-suite

watch: ## Watch for changes and rebuild (requires entr)
	@if command -v entr > /dev/null; then \
		find . -name "*.go" | entr -r make build; \
	else \
		echo "entr not installed. Install with: brew install entr (macOS) or apt install entr (Linux)"; \
	fi

# Docker targets (if needed)
docker-build: ## Build Docker image
	docker build -t packetfence-api-client-go .

docker-run: ## Run in Docker container
	docker run --rm -it \
		-e PFAPI_URL=$(URL) \
		-e PFAPI_USERNAME=$(USER) \
		-e PFAPI_PASSWORD=$(PASS) \
		packetfence-api-client-go

# Documentation
docs: ## Generate documentation
	@echo "📚 Generating documentation..."
	go doc -all > docs/api.txt
	@echo "✓ Documentation generated in docs/"

# Release preparation
release: clean test lint build ## Prepare for release
	@echo "🚀 Preparing release..."
	@echo "✓ All checks passed, ready for release"

# Environment variables with defaults
URL ?= https://localhost:9999
USER ?= admin  
PASS ?= admin

# Show current configuration
show-config: ## Show current configuration
	@echo "Current configuration:"
	@echo "  URL: $(URL)"
	@echo "  USERNAME: $(USER)"
	@echo "  PASSWORD: [hidden]"
	@echo ""
	@echo "To override, use: make target URL=https://pf.example.com:9999 USER=admin PASS=secret"