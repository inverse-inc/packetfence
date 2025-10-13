# PacketFence API Client - Makefile
# Simple commands for installation, testing, and usage

.PHONY: help install test test-basic test-all interactive examples clean lint format

# Default target
help:
	@echo "PacketFence API Client - Available Commands:"
	@echo ""
	@echo "Setup:"
	@echo "  make install          Install dependencies and setup client"
	@echo "  make requirements     Install Python requirements only"
	@echo ""
	@echo "Testing:"
	@echo "  make test            Run basic connectivity tests"
	@echo "  make test-basic      Run basic API tests with default config"
	@echo "  make test-all        Run comprehensive test suite"
	@echo "  make test-custom     Run tests with custom server (use URL=... USER=... PASS=...)"
	@echo ""
	@echo "Interactive Usage:"
	@echo "  make interactive     Start interactive CLI mode"
	@echo "  make examples        Run usage examples"
	@echo ""
	@echo "Development:"
	@echo "  make lint           Check code quality (requires flake8)"
	@echo "  make format         Format code (requires black)"
	@echo "  make clean          Clean up temporary files"
	@echo ""
	@echo "Configuration:"
	@echo "  make config         Show current configuration"
	@echo "  make config-check   Validate configuration files"
	@echo ""
	@echo "Examples:"
	@echo "  make test URL=https://pf.example.com:9999 USER=admin PASS=secret"
	@echo "  make interactive"
	@echo "  make examples URL=https://pf.example.com:9999"

# Installation targets
install:
	@echo "🚀 Setting up PacketFence API Client..."
	@python3 setup.py

requirements:
	@echo "📦 Installing Python requirements..."
	@pip3 install -r requirements.txt

# Testing targets
test: test-basic

test-basic:
	@echo "🧪 Running basic API tests..."
	@python3 pf_api_tester.py --config config.yaml --test-basic

test-all:
	@echo "🔬 Running comprehensive test suite..."
	@python3 automated_test_suite.py --config config.yaml

test-custom:
	@echo "🌐 Running tests with custom configuration..."
	@python3 pf_api_tester.py \
		--url $(or $(URL),https://localhost:9999) \
		--username $(or $(USER),admin) \
		--password $(or $(PASS),admin) \
		--no-ssl-verify \
		--test-basic

# Interactive usage
interactive:
	@echo "🖥️ Starting interactive mode..."
	@python3 pf_api_tester.py --config config.yaml --interactive

examples:
	@echo "📖 Running usage examples..."
	@python3 examples.py \
		--url $(or $(URL),https://localhost:9999) \
		--username $(or $(USER),admin) \
		--password $(or $(PASS),admin) \
		--no-ssl-verify

# Configuration management
config:
	@echo "⚙️ Current Configuration:"
	@echo ""
	@if [ -f config.yaml ]; then \
		echo "📄 config.yaml:"; \
		cat config.yaml; \
	else \
		echo "❌ config.yaml not found"; \
	fi
	@echo ""

config-check:
	@echo "✅ Validating configuration files..."
	@python3 -c "
import yaml, json, os
try:
    if os.path.exists('config.yaml'):
        with open('config.yaml') as f:
            yaml.safe_load(f)
        print('✓ config.yaml is valid')
    else:
        print('⚠ config.yaml not found')
    
    if os.path.exists('config.json'):
        with open('config.json') as f:
            json.load(f)
        print('✓ config.json is valid')
    else:
        print('⚠ config.json not found')
except Exception as e:
    print(f'❌ Configuration error: {e}')
    exit(1)
"

# Development targets
lint:
	@echo "🔍 Checking code quality..."
	@flake8 *.py --max-line-length=100 --ignore=E501,W503 || echo "Install flake8: pip install flake8"

format:
	@echo "🎨 Formatting code..."
	@black *.py --line-length=100 || echo "Install black: pip install black"

# Utility targets
clean:
	@echo "🧹 Cleaning up temporary files..."
	@rm -f *.pyc
	@rm -rf __pycache__/
	@rm -f pf_api_*.log
	@rm -f pf_api_test_results_*.json
	@rm -f pf_api_test_results_*.csv
	@echo "✓ Cleanup complete"

# Quick test targets for different scenarios
test-local:
	@make test-custom URL=https://localhost:9999 USER=admin PASS=admin

test-dev:
	@make test-custom URL=https://pf-dev.local:9999 USER=admin PASS=admin

# Installation check
check:
	@echo "🔍 Checking installation..."
	@python3 -c "
import sys
print(f'Python version: {sys.version}')
try:
    from packetfence_client import PacketFenceAPIClient
    print('✓ PacketFence API client can be imported')
    
    import requests, yaml, colorama
    print('✓ Required dependencies are available')
    
    try:
        import tabulate
        print('✓ Optional tabulate dependency available')
    except ImportError:
        print('⚠ Optional tabulate dependency not available (pip install tabulate)')
    
    print('\\n✅ Installation check passed')
except ImportError as e:
    print(f'❌ Import error: {e}')
    print('Run: make install')
    sys.exit(1)
"

# Show status of PacketFence API
status:
	@echo "📡 Checking PacketFence API status..."
	@python3 -c "
from packetfence_client import PacketFenceAPIClient
import yaml, os

config = {}
if os.path.exists('config.yaml'):
    with open('config.yaml') as f:
        config = yaml.safe_load(f)

url = config.get('server', {}).get('base_url', 'https://localhost:9999')
user = config.get('auth', {}).get('username', 'admin')
password = config.get('auth', {}).get('password', 'admin')

client = PacketFenceAPIClient(base_url=url, username=user, password=password, verify_ssl=False)
response = client.test_connection()

if response.success:
    print(f'✅ PacketFence API is responding at {url}')
    print(f'   Response time: {response.execution_time:.3f}s')
else:
    print(f'❌ PacketFence API not responding at {url}')
    print(f'   Error: {response.error}')
"

# Generate comprehensive report
report:
	@echo "📊 Generating comprehensive API report..."
	@python3 automated_test_suite.py \
		--config config.yaml \
		--output pf_api_report_$(shell date +%Y%m%d_%H%M%S).json
	@echo "✅ Report generated successfully"

# Show help for common scenarios
scenarios:
	@echo "🎯 Common Usage Scenarios:"
	@echo ""
	@echo "1. First-time setup:"
	@echo "   make install"
	@echo "   # Edit config.yaml with your server details"
	@echo "   make test"
	@echo ""
	@echo "2. Quick testing of a new server:"
	@echo "   make test-custom URL=https://pf.example.com:9999 USER=admin PASS=secret"
	@echo ""
	@echo "3. Interactive exploration:"
	@echo "   make interactive"
	@echo ""
	@echo "4. Full test suite:"
	@echo "   make test-all"
	@echo ""
	@echo "5. Generate test report:"
	@echo "   make report"
	@echo ""
	@echo "6. Run examples:"
	@echo "   make examples"