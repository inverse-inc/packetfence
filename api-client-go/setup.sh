#!/bin/bash

# PacketFence API Client (Go) - Setup Script

set -e

echo "🚀 PacketFence API Client (Go) - Setup"
echo "======================================"

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "❌ Go is not installed. Please install Go 1.19 or higher."
    echo "   Visit: https://golang.org/doc/install"
    exit 1
fi

# Check Go version
GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
echo "✓ Go version: $GO_VERSION"

# Download dependencies
echo "📦 Installing dependencies..."
go mod download
go mod tidy
echo "✓ Dependencies installed"

# Build binaries
echo "🔨 Building binaries..."
make build
echo "✓ Binaries built successfully"

# Verify build
echo "🔍 Verifying installation..."
if [[ -f "bin/pf-api-client" ]] && [[ -f "bin/pf-test-suite" ]]; then
    echo "✓ All binaries built successfully"
    echo ""
    echo "📋 Available binaries:"
    ls -la bin/
else
    echo "❌ Build verification failed"
    exit 1
fi

# Show usage examples
echo ""
echo "🎯 Quick Start Examples:"
echo "========================"
echo ""
echo "# Test connection (update URL/credentials):"
echo "  ./bin/pf-api-client connect --url https://pf.example.com:9999 --username admin --password admin"
echo ""
echo "# Run basic tests:"
echo "  ./bin/pf-api-client test basic --url https://pf.example.com:9999 --username admin --password admin"
echo ""  
echo "# Get nodes:"
echo "  ./bin/pf-api-client get nodes --limit 10 --url https://pf.example.com:9999 --username admin --password admin"
echo ""
echo "# Run automated test suite:"
echo "  ./bin/pf-test-suite test-suite --url https://pf.example.com:9999 --username admin --password admin"
echo ""
echo "# Use with configuration file:"
echo "  cp config.yaml my-config.yaml  # Edit with your settings"
echo "  ./bin/pf-api-client --config my-config.yaml get status"
echo ""
echo "# Quick test with localhost defaults:"
echo "  make quick-test"
echo ""

echo "📚 Next Steps:"
echo "=============="
echo "1. Edit config.yaml with your PacketFence server details"
echo "2. Run: make quick-test (for localhost testing)"
echo "3. Or run: ./bin/pf-api-client connect --url YOUR_URL"
echo "4. Explore: ./bin/pf-api-client --help"
echo "5. Read: README.md for detailed documentation"
echo ""
echo "🎉 Setup completed successfully!"