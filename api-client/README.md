# PacketFence API Client

A comprehensive Python client and testing suite for the PacketFence Network Access Control (NAC) API. This toolkit provides everything you need to interact with, test, and validate PacketFence API endpoints.

## 📋 Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage Examples](#usage-examples)
- [API Client Reference](#api-client-reference)
- [CLI Tool Reference](#cli-tool-reference)
- [Automated Testing](#automated-testing)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

## ✨ Features

- **🔌 Complete API Coverage**: Support for all PacketFence API endpoints as defined in the OpenAPI specification
- **🔐 Multiple Authentication Methods**: Basic auth, Bearer tokens, and API keys
- **🧪 Interactive Testing**: Command-line interface for manual API exploration and testing
- **🤖 Automated Test Suite**: Comprehensive automated testing with validation and reporting
- **📊 Response Validation**: Built-in validation for common API response patterns
- **⚙️ Configurable**: YAML/JSON configuration files for easy customization
- **📈 Performance Monitoring**: Request timing and performance metrics
- **🎨 Colorized Output**: Beautiful, readable console output with color coding
- **💾 Result Export**: Save test results in JSON or CSV format

## 🚀 Quick Start

1. **Install dependencies**:
```bash
cd /home/faduran/sources/packetfence/api-client
pip install -r requirements.txt
```

2. **Test the connection**:
```bash
python pf_api_tester.py --url https://your-pf-server:9999 --username admin --password admin --test-basic
```

3. **Start interactive mode**:
```bash
python pf_api_tester.py --interactive
```

4. **Run comprehensive tests**:
```bash
python automated_test_suite.py --url https://your-pf-server:9999
```

## 📦 Installation

### Prerequisites

- Python 3.7 or higher
- PacketFence server with API enabled
- Network access to PacketFence API (default port 9999)

### Dependencies Installation

```bash
# Install core dependencies
pip install -r requirements.txt

# For development and extended features
pip install tabulate jsonschema pytest black flake8
```

### Verify Installation

```bash
python -c "from packetfence_client import PacketFenceAPIClient; print('✓ Installation successful')"
```

## ⚙️ Configuration

The toolkit supports both YAML and JSON configuration files for easy customization.

### Example Configuration (config.yaml)

```yaml
server:
  base_url: "https://localhost:9999"
  verify_ssl: false
  timeout: 30

auth:
  username: "admin"
  password: "admin"
  # token: "your_bearer_token"
  # api_key: "your_api_key"

testing:
  max_retries: 3
  save_results: true
  results_format: "json"
  delay_between_requests: 0.1
```

### Using Configuration Files

```bash
# Use YAML config
python pf_api_tester.py --config config.yaml --interactive

# Use JSON config
python pf_api_tester.py --config config.json --test-all
```

## 📖 Usage Examples

### Basic API Client Usage

```python
from packetfence_client import PacketFenceAPIClient

# Initialize client
client = PacketFenceAPIClient(
    base_url="https://pf.example.com:9999",
    username="admin",
    password="admin",
    verify_ssl=False
)

# Test connection
response = client.test_connection()
print(f"Connection: {'✓' if response.success else '✗'}")

# Get nodes
nodes = client.get_nodes(limit=10)
if nodes.success:
    print(f"Found {len(nodes.data.get('items', []))} nodes")

# Search for specific node
search_result = client.search_nodes({
    "query": {"mac": "aa:bb:cc:dd:ee:ff"}
})

# Get system configuration
config = client.get_config("general")
```

### Interactive CLI Usage

```bash
# Start interactive mode
python pf_api_tester.py --interactive

# In interactive mode:
pf-api> connect https://pf.example.com:9999
pf-api> status
pf-api> get /api/v1/nodes?limit=5
pf-api> endpoints
pf-api> test-basic
pf-api> quit
```

### Batch Testing

```bash
# Run basic connectivity tests
python pf_api_tester.py --url https://pf.example.com:9999 --test-basic

# Run comprehensive test suite
python pf_api_tester.py --config config.yaml --test-all

# Test specific endpoint
python pf_api_tester.py --url https://pf.example.com:9999 --get /api/v1/nodes

# Test with POST data
python pf_api_tester.py --url https://pf.example.com:9999 --post /api/v1/nodes/search '{"query":{"limit":5}}'
```

### Automated Test Suite

```bash
# Run full automated test suite
python automated_test_suite.py --url https://pf.example.com:9999 --username admin --password secret

# Save results to specific file
python automated_test_suite.py --url https://pf.example.com:9999 --output my_test_results.json

# Run with custom delay between requests
python automated_test_suite.py --url https://pf.example.com:9999 --delay 0.5
```

## 🔧 API Client Reference

### PacketFenceAPIClient Class

The main API client class providing methods for all PacketFence endpoints.

#### Initialization

```python
client = PacketFenceAPIClient(
    base_url="https://localhost:9999",    # PacketFence API URL
    username=None,                        # Basic auth username
    password=None,                        # Basic auth password
    token=None,                          # Bearer token
    api_key=None,                        # API key
    verify_ssl=False,                    # SSL verification
    timeout=30,                          # Request timeout
    max_retries=3                        # Max retry attempts
)
```

#### Core HTTP Methods

```python
# GET request
response = client.get("/api/v1/nodes", params={"limit": 10})

# POST request
response = client.post("/api/v1/nodes", json_data={"mac": "aa:bb:cc:dd:ee:ff"})

# PUT request
response = client.put("/api/v1/node/123", json_data={"status": "reg"})

# DELETE request
response = client.delete("/api/v1/node/123")
```

#### Specialized Methods

```python
# Node management
nodes = client.get_nodes(limit=25, cursor=0)
node = client.get_node("aa:bb:cc:dd:ee:ff")
result = client.create_node({"mac": "aa:bb:cc:dd:ee:ff", "pid": "user1"})
result = client.update_node("aa:bb:cc:dd:ee:ff", {"status": "reg"})
result = client.delete_node("aa:bb:cc:dd:ee:ff")

# User management
users = client.get_users(limit=25)
user = client.get_user("user123")
result = client.create_user({"pid": "user123", "email": "user@example.com"})

# System information
status = client.test_connection()
services = client.get_services_status()
config = client.get_config("general")

# Reports
reports = client.get_reports()
report_data = client.search_report("node_report", {"query": {"limit": 10}})
```

### APIResponse Class

All API methods return an `APIResponse` object with the following attributes:

```python
response = client.get_nodes()

print(response.status_code)    # HTTP status code
print(response.success)        # True if 2xx status
print(response.data)          # Parsed JSON response
print(response.headers)       # Response headers dict
print(response.error)         # Error message if failed
print(response.execution_time) # Request duration in seconds
```

## 🖥️ CLI Tool Reference

### Command Line Options

```bash
python pf_api_tester.py [OPTIONS]

Connection Options:
  --url URL                 PacketFence API base URL
  --username USER           Username for authentication
  --password PASS           Password for authentication
  --token TOKEN             Bearer token for authentication
  --config FILE             Configuration file (JSON or YAML)
  --no-ssl-verify           Disable SSL verification

Testing Modes:
  --interactive, -i         Start interactive mode
  --test-basic             Run basic connectivity tests
  --test-all               Run comprehensive test suite

Individual Requests:
  --get ENDPOINT           Make GET request to endpoint
  --post ENDPOINT DATA     Make POST request with JSON data

Output Options:
  --verbose, -v            Verbose output
  --quiet, -q              Quiet output
```

### Interactive Commands

When in interactive mode (`--interactive`), use these commands:

| Command | Description |
|---------|-------------|
| `connect [url]` | Connect to PacketFence API |
| `status` | Test connection and get server status |
| `endpoints` | List all available API endpoints |
| `get <endpoint>` | Make GET request to endpoint |
| `post <endpoint> <json>` | Make POST request with JSON data |
| `test-basic` | Run basic connectivity tests |
| `test-all` | Run comprehensive test suite |
| `help`, `h` | Show help message |
| `quit`, `exit`, `q` | Exit the program |

## 🤖 Automated Testing

The automated test suite provides comprehensive validation of all API endpoints.

### Running Tests

```bash
# Basic usage
python automated_test_suite.py --url https://pf.example.com:9999

# With authentication
python automated_test_suite.py \
  --url https://pf.example.com:9999 \
  --username admin \
  --password secret

# With configuration file
python automated_test_suite.py --config config.yaml

# Save results to specific file
python automated_test_suite.py \
  --url https://pf.example.com:9999 \
  --output test_results_$(date +%Y%m%d).json
```

### Test Categories

The automated test suite covers:

1. **System Status Tests**: API health and service status
2. **Configuration Tests**: System configuration retrieval
3. **Data Management Tests**: Node, user, and violation management
4. **Reporting Tests**: Dynamic report access
5. **Search Tests**: Search functionality validation
6. **HTTP Method Tests**: OPTIONS requests for API discovery

### Test Result Analysis

Test results include:

- **Success Rate**: Percentage of passed tests
- **Performance Metrics**: Response times and slow endpoint identification
- **Error Analysis**: Detailed error messages for failed tests
- **Response Validation**: Content validation beyond HTTP status codes

## 🔬 Advanced Usage

### Custom Validation Functions

```python
def validate_node_response(response):
    \"\"\"Custom validation for node responses\"\"\"
    if not response.data or 'mac' not in response.data:
        return False, "Response missing MAC address"
    
    mac = response.data['mac']
    if not re.match(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$', mac):
        return False, "Invalid MAC address format"
    
    return True, "Valid node response"

# Use in test case
test_case = TestCase(
    name="Custom Node Validation",
    method="GET",
    endpoint="/api/v1/node/aa:bb:cc:dd:ee:ff",
    validation_func=validate_node_response
)
```

### Batch Operations

```python
# Batch node creation
nodes_to_create = [
    {"mac": "aa:bb:cc:dd:ee:01", "pid": "user1"},
    {"mac": "aa:bb:cc:dd:ee:02", "pid": "user2"},
    {"mac": "aa:bb:cc:dd:ee:03", "pid": "user3"},
]

created_nodes = []
for node_data in nodes_to_create:
    response = client.create_node(node_data)
    if response.success:
        created_nodes.append(node_data['mac'])
    else:
        print(f"Failed to create node {node_data['mac']}: {response.error}")

print(f"Successfully created {len(created_nodes)} nodes")
```

### Error Handling and Retry Logic

```python
from time import sleep

def robust_api_call(client, method, endpoint, max_retries=5, **kwargs):
    \"\"\"API call with exponential backoff retry\"\"\"
    for attempt in range(max_retries):
        try:
            if method.upper() == 'GET':
                response = client.get(endpoint, **kwargs)
            elif method.upper() == 'POST':
                response = client.post(endpoint, **kwargs)
            else:
                raise ValueError(f"Unsupported method: {method}")
            
            if response.success or response.status_code in [404, 403]:
                # Don't retry for client errors
                return response
            
            if attempt < max_retries - 1:
                wait_time = (2 ** attempt) + random.uniform(0, 1)
                print(f"Request failed, retrying in {wait_time:.1f}s...")
                sleep(wait_time)
            
        except Exception as e:
            if attempt < max_retries - 1:
                print(f"Exception occurred, retrying: {e}")
                sleep(2 ** attempt)
            else:
                raise
    
    return response

# Usage
response = robust_api_call(client, 'GET', '/api/v1/nodes', params={'limit': 10})
```

### Performance Monitoring

```python
import time
from collections import defaultdict

class PerformanceMonitor:
    def __init__(self, client):
        self.client = client
        self.metrics = defaultdict(list)
    
    def monitored_request(self, method, endpoint, **kwargs):
        start_time = time.time()
        
        if method.upper() == 'GET':
            response = self.client.get(endpoint, **kwargs)
        elif method.upper() == 'POST':
            response = self.client.post(endpoint, **kwargs)
        
        execution_time = time.time() - start_time
        
        self.metrics[endpoint].append({
            'method': method,
            'status_code': response.status_code,
            'execution_time': execution_time,
            'success': response.success,
            'timestamp': time.time()
        })
        
        return response
    
    def get_performance_summary(self):
        summary = {}
        for endpoint, calls in self.metrics.items():
            times = [call['execution_time'] for call in calls]
            summary[endpoint] = {
                'calls': len(calls),
                'avg_time': sum(times) / len(times),
                'min_time': min(times),
                'max_time': max(times),
                'success_rate': sum(call['success'] for call in calls) / len(calls)
            }
        return summary

# Usage
monitor = PerformanceMonitor(client)
response = monitor.monitored_request('GET', '/api/v1/nodes')
summary = monitor.get_performance_summary()
```

## 🐛 Troubleshooting

### Common Issues and Solutions

#### 1. SSL Certificate Errors

**Error**: `SSL: CERTIFICATE_VERIFY_FAILED`

**Solution**:
```bash
# Disable SSL verification (for development/testing only)
python pf_api_tester.py --no-ssl-verify --url https://pf.example.com:9999

# Or in Python code
client = PacketFenceAPIClient(base_url="https://pf.example.com:9999", verify_ssl=False)
```

#### 2. Authentication Failures

**Error**: `HTTP 401: Unauthorized`

**Solutions**:
```bash
# Check credentials
python pf_api_tester.py --url https://pf.example.com:9999 --username admin --password admin

# Use token authentication
python pf_api_tester.py --url https://pf.example.com:9999 --token "your_bearer_token"

# Verify API user permissions in PacketFence admin interface
```

#### 3. Connection Timeouts

**Error**: `Connection timeout` or `Read timeout`

**Solutions**:
```python
# Increase timeout
client = PacketFenceAPIClient(
    base_url="https://pf.example.com:9999",
    timeout=60  # Increase to 60 seconds
)

# Or use configuration file
# config.yaml:
server:
  timeout: 60
```

#### 4. Large Response Handling

**Issue**: Large responses cause memory issues or slow processing

**Solution**:
```python
# Use pagination for large datasets
response = client.get_nodes(limit=50)  # Smaller batch size

# Process in chunks
def process_all_nodes(client, batch_size=50):
    cursor = 0
    while True:
        response = client.get_nodes(limit=batch_size, cursor=cursor)
        if not response.success or not response.data.get('items'):
            break
        
        # Process batch
        for node in response.data['items']:
            print(f"Processing node: {node.get('mac')}")
        
        # Update cursor for next batch
        if 'nextCursor' in response.data:
            cursor = response.data['nextCursor']
        else:
            break
```

#### 5. API Rate Limiting

**Error**: `HTTP 429: Too Many Requests`

**Solution**:
```python
# Add delays between requests
import time

def rate_limited_requests(client, endpoints, delay=1.0):
    results = []
    for endpoint in endpoints:
        response = client.get(endpoint)
        results.append(response)
        time.sleep(delay)  # Wait between requests
    return results

# Or use the built-in delay in test suite
python automated_test_suite.py --delay 0.5  # 500ms between requests
```

### Debug Mode

Enable debug logging to troubleshoot issues:

```python
import logging

# Enable debug logging
logging.basicConfig(level=logging.DEBUG)

# Or in CLI tool
python pf_api_tester.py --verbose --url https://pf.example.com:9999
```

### Checking API Availability

```bash
# Test basic connectivity
curl -k https://pf.example.com:9999/api/v1/status

# Check if API is responding
python -c "
import requests
try:
    r = requests.get('https://pf.example.com:9999/api/v1/status', verify=False, timeout=10)
    print(f'API Status: {r.status_code}')
except Exception as e:
    print(f'API Error: {e}')
"
```

### Performance Optimization

For better performance with large-scale testing:

1. **Use connection pooling**: The client already uses `requests.Session` for connection reuse
2. **Batch operations**: Process multiple items in single requests when possible
3. **Parallel processing**: Use threading for independent API calls
4. **Optimize queries**: Use specific fields and filters to reduce response sizes

```python
import concurrent.futures
from threading import Lock

class ParallelAPITester:
    def __init__(self, client, max_workers=5):
        self.client = client
        self.max_workers = max_workers
        self.results_lock = Lock()
        self.results = []
    
    def test_endpoints_parallel(self, endpoints):
        with concurrent.futures.ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            futures = {executor.submit(self.client.get, endpoint): endpoint 
                      for endpoint in endpoints}
            
            for future in concurrent.futures.as_completed(futures):
                endpoint = futures[future]
                try:
                    response = future.result()
                    with self.results_lock:
                        self.results.append({
                            'endpoint': endpoint,
                            'success': response.success,
                            'status_code': response.status_code,
                            'execution_time': response.execution_time
                        })
                except Exception as e:
                    print(f"Error testing {endpoint}: {e}")

# Usage
parallel_tester = ParallelAPITester(client)
endpoints = ['/api/v1/nodes', '/api/v1/users', '/api/v1/violations']
parallel_tester.test_endpoints_parallel(endpoints)
```

---

## 📞 Support

For issues, questions, or contributions:

1. **PacketFence Community**: [PacketFence Forums](https://packetfence.org/support/)
2. **GitHub Issues**: Report bugs or request features
3. **Documentation**: [PacketFence Official Docs](https://packetfence.org/documentation/)

## 📄 License

This API client toolkit is provided under the same license as PacketFence (GNU General Public License v2.0).

---

*Happy testing! 🚀*