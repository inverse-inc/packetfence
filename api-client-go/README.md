# PacketFence API Client (Go)

A comprehensive Go client library and CLI tools for the PacketFence Network Access Control (NAC) API. This toolkit provides everything you need to interact with, test, and validate PacketFence API endpoints using Go.

## 📋 Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage Examples](#usage-examples)
- [API Client Library](#api-client-library)
- [CLI Tools](#cli-tools)
- [Configuration](#configuration)
- [Testing Suite](#testing-suite)
- [Development](#development)
- [Performance](#performance)

## ✨ Features

- **🔌 Complete API Coverage**: Support for all PacketFence API endpoints as defined in the OpenAPI specification
- **🔐 Multiple Authentication Methods**: Basic auth, Bearer tokens, and API keys
- **🧪 CLI Testing Tools**: Interactive and automated testing capabilities
- **⚡ High Performance**: Built with Go's excellent HTTP client and concurrency support
- **🛡️ Type Safety**: Strong typing with comprehensive error handling
- **📊 Performance Monitoring**: Built-in request timing and performance metrics
- **🎨 Colorized Output**: Beautiful, readable console output with color coding
- **💾 Result Export**: Save test results in JSON format
- **🔧 Configurable**: YAML/JSON configuration files and environment variables

## 🚀 Quick Start

1. **Build the tools**:
```bash
cd /home/faduran/sources/packetfence/api-client-go
make build
```

2. **Test connection**:
```bash
make quick-test
```

3. **Run comprehensive tests**:
```bash
make test-comprehensive URL=https://your-pf-server:9999 USER=admin PASS=yourpassword
```

4. **Use CLI tool**:
```bash
./bin/pf-api-client connect --url https://your-pf-server:9999 --username admin --password admin
./bin/pf-api-client get nodes --limit 10
```

## 📦 Installation

### Prerequisites

- Go 1.19 or higher
- PacketFence server with API enabled
- Network access to PacketFence API (default port 9999)

### Build from Source

```bash
# Clone or navigate to the directory
cd /home/faduran/sources/packetfence/api-client-go

# Install dependencies and build
make deps
make build

# Install to $GOPATH/bin (optional)
make install
```

### Verify Installation

```bash
./bin/pf-api-client --help
./bin/pf-test-suite --help
```

## 📖 Usage Examples

### Using the Go Library

```go
package main

import (
    "fmt"
    "time"
    
    pfclient "github.com/inverse-inc/packetfence-api-client-go"
)

func main() {
    // Create client configuration
    config := &pfclient.Config{
        BaseURL:   "https://pf.example.com:9999",
        Username:  "admin",
        Password:  "admin",
        VerifySSL: false,
        Timeout:   30 * time.Second,
    }
    
    // Create client
    client, err := pfclient.NewClient(config)
    if err != nil {
        panic(err)
    }
    
    // Test connection
    response, err := client.TestConnection()
    if err != nil {
        panic(err)
    }
    
    if response.Success {
        fmt.Printf("✅ Connected! Response time: %v\n", response.ExecutionTime)
    }
    
    // Get nodes
    nodes, err := client.GetNodes(10, 0, []string{"mac", "pid"})
    if err != nil {
        panic(err)
    }
    
    if nodes.Success {
        fmt.Printf("Found nodes: %+v\n", nodes.Data)
    }
}
```

### Using the CLI Tool

```bash
# Connect and test
./bin/pf-api-client connect --url https://pf.example.com:9999

# Get system status
./bin/pf-api-client get status

# Get nodes with pagination
./bin/pf-api-client get nodes --limit 50 --cursor 0

# Get users
./bin/pf-api-client get users --limit 25

# Run basic tests
./bin/pf-api-client test basic

# Run comprehensive tests  
./bin/pf-api-client test comprehensive

# List all endpoints
./bin/pf-api-client endpoints

# Make custom POST request
./bin/pf-api-client post /api/v1/nodes/search '{"query":{"limit":5}}'
```

### Running the Test Suite

```bash
# Run automated test suite
./bin/pf-test-suite test-suite --url https://pf.example.com:9999

# Save results to file
./bin/pf-test-suite test-suite --output my_results.json

# Use configuration file
./bin/pf-test-suite test-suite --config config.yaml
```

## 🔧 API Client Library

### Client Configuration

```go
type Config struct {
    BaseURL     string        // PacketFence API base URL
    Username    string        // Basic auth username
    Password    string        // Basic auth password  
    Token       string        // Bearer token
    APIKey      string        // API key
    VerifySSL   bool          // SSL certificate verification
    Timeout     time.Duration // Request timeout
    MaxRetries  int           // Maximum retry attempts
    UserAgent   string        // HTTP User-Agent header
}
```

### Available Methods

#### Core HTTP Methods
```go
// HTTP methods with context support
client.GET(ctx, endpoint, params)
client.POST(ctx, endpoint, body)
client.PUT(ctx, endpoint, body) 
client.PATCH(ctx, endpoint, body)
client.DELETE(ctx, endpoint)
client.OPTIONS(ctx, endpoint)

// Convenience methods (use background context)
client.Get(endpoint, params)
client.Post(endpoint, body)
client.Put(endpoint, body)
client.Delete(endpoint)
```

#### PacketFence-Specific Methods
```go
// System
client.TestConnection()
client.GetServicesStatus()
client.GetConfig(section)

// Nodes  
client.GetNodes(limit, cursor, fields)
client.GetNode(nodeID)
client.CreateNode(nodeData)
client.UpdateNode(nodeID, nodeData)
client.DeleteNode(nodeID)
client.SearchNodes(criteria)

// Users
client.GetUsers(limit, cursor)
client.GetUser(userID)
client.CreateUser(userData)
client.UpdateUser(userID, userData)  
client.DeleteUser(userID)
client.SearchUsers(criteria)

// Reports
client.GetReports()
client.GetReport(reportID)
client.SearchReport(reportID, criteria)

// Network devices
client.GetSwitches()
client.GetSwitch(switchID)

// And many more...
```

### Response Handling

```go
type APIResponse struct {
    StatusCode    int                    // HTTP status code
    Data          map[string]interface{} // Parsed JSON response
    RawData       json.RawMessage       // Raw response bytes
    Headers       http.Header           // HTTP headers
    Success       bool                  // True if 2xx status
    Error         string                // Error message if failed
    ExecutionTime time.Duration         // Request duration
}
```

## 🖥️ CLI Tools

### pf-api-client

The main CLI tool for interactive API testing:

```bash
# Connection
pf-api-client connect [flags]

# Testing  
pf-api-client test basic
pf-api-client test comprehensive

# GET requests
pf-api-client get nodes [flags]
pf-api-client get users [flags]  
pf-api-client get status
pf-api-client get reports

# POST requests
pf-api-client post <endpoint> <json-data>

# Information
pf-api-client endpoints
```

**Common Flags:**
- `--url`: PacketFence API base URL
- `--username`: Username for authentication
- `--password`: Password for authentication  
- `--token`: Bearer token for authentication
- `--verify-ssl`: Enable SSL verification
- `--config`: Configuration file path

### pf-test-suite

Automated test suite with comprehensive validation:

```bash
# Run full test suite
pf-test-suite test-suite [flags]

# Common flags
--save-results    # Save results to file (default: true)
--output         # Output file path
--delay          # Delay between requests
```

## ⚙️ Configuration

### Configuration File (config.yaml)

```yaml
server:
  base_url: "https://localhost:9999"
  verify_ssl: false
  timeout: 30s
  max_retries: 3

auth:
  username: "admin"
  password: "admin"
  # token: "bearer_token"
  # api_key: "api_key"

testing:
  save_results: true
  results_format: "json"
  delay_between_requests: 100ms

endpoints:
  read_only_tests:
    - "/api/v1/status"
    - "/api/v1/nodes"
    # ... more endpoints
```

### Environment Variables

All configuration options can be set via environment variables with the `PFAPI_` prefix:

```bash
export PFAPI_URL="https://pf.example.com:9999"
export PFAPI_USERNAME="admin"
export PFAPI_PASSWORD="secret"
export PFAPI_VERIFY_SSL="false"
```

## 🧪 Testing Suite

### Test Categories

The automated test suite covers:

1. **System Tests**: API health, service status, connectivity
2. **Configuration Tests**: System configuration retrieval
3. **Data Management Tests**: CRUD operations for nodes, users, violations
4. **Reporting Tests**: Dynamic report access and search
5. **Performance Tests**: Response time monitoring
6. **Error Handling Tests**: Invalid requests and error responses

### Test Results

Test results include:
- Success/failure status
- HTTP status codes  
- Response times
- Error messages
- Performance metrics
- Detailed JSON export

### Example Test Output

```
🧪 Running PacketFence API Test Suite
============================================================

[1/12] Check system status and health
  Running: System Status
    ✓ System Status (200, 234ms)

[2/12] Check status of PacketFence services  
  Running: Services Status
    ✓ Services Status (200, 156ms)

...

============================================================
📊 Test Execution Summary
============================================================
Total Tests:     12
Passed:          11  
Failed:          1
Success Rate:    91.7%
Total Time:      2.1s
Average Time:    175ms

❌ Failed Tests:
  • Get DHCP Options: HTTP 404: Not Found

💾 Test results saved to: pf_api_test_results_20241013_142530.json
```

## 🚀 Development

### Building

```bash
# Build all binaries
make build

# Build with race detector (development)
make dev-build

# Clean build artifacts
make clean
```

### Testing

```bash
# Run Go tests
make test

# Run linters
make lint

# Format code
make fmt
```

### Watching for Changes

```bash
# Auto-rebuild on file changes (requires entr)
make watch
```

### Makefile Targets

```bash
make help              # Show all available targets
make build            # Build all binaries
make test             # Run tests
make clean            # Clean artifacts
make install          # Install to $GOPATH/bin
make quick-test       # Quick test with defaults
make connect          # Test connection  
make get-nodes        # Get nodes from API
make test-suite       # Run automated test suite
```

## ⚡ Performance

### Benchmarks

The Go client provides excellent performance:

- **Concurrent requests**: Full goroutine support
- **Connection pooling**: Automatic HTTP connection reuse
- **Low memory usage**: Efficient JSON parsing and minimal allocations
- **Fast startup**: Sub-second binary startup time

### Performance Monitoring

All requests include detailed timing information:

```go
response, err := client.GetNodes(100, 0, nil)
fmt.Printf("Request took: %v\n", response.ExecutionTime)
```

### Optimization Tips

1. **Use pagination**: Limit large result sets with `limit` parameters
2. **Specify fields**: Use field selection to reduce response size
3. **Connection reuse**: Use the same client instance for multiple requests
4. **Concurrent requests**: Use goroutines for parallel API calls

```go
// Example: Concurrent API calls
var wg sync.WaitGroup
results := make(chan *pfclient.APIResponse, 3)

endpoints := []string{"/api/v1/nodes", "/api/v1/users", "/api/v1/violations"}

for _, endpoint := range endpoints {
    wg.Add(1)
    go func(ep string) {
        defer wg.Done()
        resp, _ := client.Get(ep, map[string]string{"limit": "10"})
        results <- resp
    }(endpoint)
}

wg.Wait()
close(results)

for resp := range results {
    fmt.Printf("Response: %d (%v)\n", resp.StatusCode, resp.ExecutionTime)
}
```

## 🔍 Troubleshooting

### Common Issues

**SSL Certificate Errors:**
```bash
# Disable SSL verification for development
--verify-ssl=false
# Or set in config
verify_ssl: false
```

**Connection Timeouts:**
```bash  
# Increase timeout
--timeout 60
# Or set in config
timeout: 60s
```

**Authentication Failures:**
```bash
# Verify credentials
./bin/pf-api-client connect --url https://pf.example.com:9999 --username admin --password admin
```

### Debug Mode

Enable verbose logging:
```bash
export PFAPI_LOG_LEVEL=debug
./bin/pf-api-client get status
```

### Performance Issues

Monitor slow requests:
```bash
./bin/pf-test-suite test-suite --delay 500ms
```

## 📞 Support

For issues, questions, or contributions:

1. **PacketFence Community**: [PacketFence Forums](https://packetfence.org/support/)
2. **Documentation**: [PacketFence Official Docs](https://packetfence.org/documentation/)
3. **GitHub Issues**: Report bugs or request features

## 📄 License

This Go API client toolkit is provided under the same license as PacketFence (GNU General Public License v2.0).

---

*Built with ❤️ and Go for the PacketFence community* 🚀