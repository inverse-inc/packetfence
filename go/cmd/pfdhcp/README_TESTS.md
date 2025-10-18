# PFDHCP Unit Tests

## Overview

This directory contains comprehensive unit tests for the PacketFence DHCP server (pfdhcp). The tests cover various components including database operations, configuration management, API endpoints, worker pools, and utility functions.

## Quick Start

Simply run the provided test script:

```bash
./run_tests.sh
```

This will run all unit tests that don't require a full PacketFence environment.

## Test Summary

**Total Test Files**: 7  
**Total Tests**: 40+  
**Passing Tests**: 30+  
**Skipped Tests**: 10+ (require PacketFence environment)

### Test Status
- ✅ **Constants**: MAC addresses, timeouts, configurations
- ✅ **Structures**: All data structures and JSON serialization
- ✅ **API Endpoints**: HTTP handlers and caching
- ✅ **Worker Pool**: Job creation and context handling
- ✅ **Utility Functions**: IPv4/IPv6 detection, string helpers
- ⏭️ **Database Operations**: Skipped (requires database)
- ⏭️ **pfconfig Operations**: Skipped (requires pfconfig service)

## Important: Running Tests

**The tests require PacketFence initialization due to the pfcrypt package.** There are two options:

### Option 1: Run in PacketFence Environment
If you have PacketFence installed with `/usr/local/pf/conf/system_init_key`:
```bash
cd /home/fdurand/sources/packetfence/go/cmd/pfdhcp
go test -v
```

### Option 2: Create Mock Environment
If testing outside PacketFence, create a mock key file:
```bash
# Create mock configuration directory
sudo mkdir -p /usr/local/pf/conf

# Create mock system init key
sudo sh -c 'echo "mock_key_for_testing_only" > /usr/local/pf/conf/system_init_key'

# Run tests
go test -v
```

### Option 3: Set Environment Variable
```bash
export PF_SYSTEM_INIT_KEY="mock_key_for_testing_only"
go test -v
```

## Test Files

### 1. `main_test.go`
Tests for main package constants and configuration values:
- **TestConstants**: Validates all constant values (FreeMac, FakeMac, cache durations)
- **TestCacheDurations**: Ensures cache durations are within reasonable ranges
- **TestTimeoutValues**: Validates timeout configurations

### 2. `config_test.go`
Tests for DHCP configuration structures:
- **TestNewDHCPConfig**: Validates DHCP config initialization
- **TestDHCPHandlerCreation**: Tests DHCPHandler struct creation
- **TestInterfaceCreation**: Tests Interface struct initialization
- **TestNetworkCreation**: Tests Network configuration
- **TestBootpConstants**: Validates BOOTP port constants (67/68)

### 3. `keysoption_test.go`
Tests for MySQL key-value storage operations:
- **TestMysqlInsertInterface**: Documents MysqlInsert function interface
- **TestMysqlGetInterface**: Documents MysqlGet function interface
- **TestMysqlOperationsContextTimeout**: Documents context timeout handling
- **TestMysqlIntegration**: Integration test template (requires database)
- **TestContextCancellation**: Tests context cancellation behavior

### 4. `utils_helpers_test.go`
Tests for utility helper functions:
- **TestIsIPv4**: Validates IPv4 address detection
- **TestIsIPv6**: Validates IPv6 address detection
- **TestZeroDate**: Tests ZeroDate constant
- **TestNodeInfoStruct**: Tests NodeInfo structure
- **TestStringInSlice**: Tests string slice search function
- **TestSetOptionServerIdentifier**: Tests server identifier option logic
- **TestInterfaceScopeFromMac**: Tests MAC-based interface scope lookup

### 5. `api_test.go`
Tests for HTTP API endpoints:
- **TestHandleIP2Mac**: Tests IP-to-MAC lookup endpoint
- **TestNodeStruct**: Tests Node JSON serialization
- **TestStatsStruct**: Tests Stats JSON serialization
- **TestAPIReqStruct**: Tests API request structure
- **TestInfoStruct**: Tests API Info response structure
- **TestOptionsStruct**: Tests DHCP options structure
- **TestItemsStruct**: Tests Items response structure
- **TestIPv4ToInt**: Tests IPv4 to integer conversion

### 6. `workers_pool_test.go`
Tests for worker pool and job processing:
- **TestJob**: Tests job structure creation
- **TestJobStruct**: Validates job fields
- **TestJobCreationWithContext**: Tests job context handling
- **TestJobWithDHCPPacket**: Tests job with DHCP packet data

## Running Tests

### Quick Start (Recommended)

Run unit tests that don't require PacketFence services:

```bash
export PF_SYSTEM_INIT_KEY="test_key_12345678901234567890123456789012"
cd /home/fdurand/sources/packetfence/go/cmd/pfdhcp
go test -v -run "^Test(FreeMac|FakeMac|BootpPorts|ZeroDate|NodeInfo|HandleIP2Mac|Struct|NewDHCP|DHCPHandler|Interface|Network|Context|IsIPv|StringInSlice|SetOption)"
```

This runs all tests that work without a full PacketFence environment (constants, structures, basic helpers).

## Test Categories

### Unit Tests
These tests don't require external dependencies:
- Constants and struct tests
- Helper function tests
- JSON serialization tests
- Basic validation tests

### Integration Tests
These tests require PacketFence infrastructure (currently skipped):
- Database operations (MysqlInsert, MysqlGet)
- pfconfig operations
- Filter client operations

## Notes

1. **Database Tests**: Tests requiring database connections are currently documented but skipped. To run them, you need:
   - A running MySQL/MariaDB instance
   - Proper PacketFence database schema
   - Connection credentials in pfconfig

2. **Mock Data**: Most tests use mock data and don't require actual PacketFence installation.

3. **Context Handling**: Tests verify proper context timeout and cancellation handling.

4. **Error Handling**: Tests cover both success and error cases where applicable.

## Adding New Tests

When adding new tests:
1. Follow the existing naming convention: `Test<FunctionName>`
2. Use table-driven tests for multiple test cases
3. Include both positive and negative test cases
4. Document integration tests that require external dependencies
5. Use `t.Skip()` for tests requiring special setup

## Test Coverage

Current test coverage focuses on:
- ✅ Constants and configuration
- ✅ Data structures and JSON serialization
- ✅ Utility helper functions
- ✅ API endpoint structures
- ✅ Worker pool job handling
- ⚠️ Database operations (documented, needs environment)
- ⚠️ Full integration tests (needs PacketFence installation)

## Future Improvements

- Add mock database for MySQL operations
- Add benchmarks for performance-critical functions
- Add integration tests with testcontainers
- Increase coverage for DHCP packet handling
- Add tests for concurrent operations
- Add fuzzing tests for packet parsing
