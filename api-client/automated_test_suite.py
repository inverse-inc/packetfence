#!/usr/bin/env python3
"""
PacketFence API Automated Test Suite

Comprehensive automated testing suite that validates all PacketFence API endpoints
with sample data and expected responses based on the OpenAPI specification.
"""

import json
import sys
import os
import time
from typing import Dict, Any, List, Tuple
from dataclasses import dataclass
from datetime import datetime
import argparse

# Add the current directory to the path to import our client
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from packetfence_client import PacketFenceAPIClient, APIResponse


@dataclass
class TestCase:
    """Individual test case definition"""
    name: str
    method: str
    endpoint: str
    data: Dict = None
    headers: Dict = None
    expected_status: List[int] = None
    validation_func: callable = None
    description: str = ""
    cleanup_func: callable = None


class PacketFenceTestSuite:
    """Automated test suite for PacketFence API"""
    
    def __init__(self, client: PacketFenceAPIClient, config: Dict = None):
        """Initialize test suite with API client and configuration"""
        self.client = client
        self.config = config or {}
        self.test_results = []
        self.created_resources = []  # Track created resources for cleanup
        
    def validate_json_response(self, response: APIResponse) -> Tuple[bool, str]:
        """Validate that response contains valid JSON"""
        if not response.data:
            return False, "No data in response"
        
        if not isinstance(response.data, dict):
            return False, "Response data is not a JSON object"
        
        return True, "Valid JSON response"
    
    def validate_list_response(self, response: APIResponse) -> Tuple[bool, str]:
        """Validate that response contains a list or paginated result"""
        if not response.data:
            return False, "No data in response"
        
        # Check for common list response patterns
        if isinstance(response.data, list):
            return True, f"Valid list response with {len(response.data)} items"
        
        if isinstance(response.data, dict):
            # Check for paginated response
            if 'items' in response.data:
                items = response.data['items']
                if isinstance(items, list):
                    return True, f"Valid paginated response with {len(items)} items"
            
            # Check for single item response
            if 'item' in response.data:
                return True, "Valid single item response"
        
        return False, "Response does not contain expected list or item structure"
    
    def validate_status_response(self, response: APIResponse) -> Tuple[bool, str]:
        """Validate system status response"""
        if not response.data or not isinstance(response.data, dict):
            return False, "Invalid status response format"
        
        # Look for common status fields
        status_fields = ['status', 'version', 'services', 'uptime']
        found_fields = [field for field in status_fields if field in response.data]
        
        if found_fields:
            return True, f"Valid status response with fields: {', '.join(found_fields)}"
        
        return False, "Status response missing expected fields"
    
    def validate_config_response(self, response: APIResponse) -> Tuple[bool, str]:
        """Validate configuration response"""
        if not response.data or not isinstance(response.data, dict):
            return False, "Invalid configuration response format"
        
        # Configuration responses should have nested structure
        if any(isinstance(value, dict) for value in response.data.values()):
            return True, "Valid configuration response with nested structure"
        
        return True, "Valid configuration response"
    
    def generate_test_cases(self) -> List[TestCase]:
        """Generate comprehensive test cases based on PacketFence API"""
        test_cases = []
        
        # System and Status Tests
        test_cases.extend([
            TestCase(
                name="System Status",
                method="GET",
                endpoint="/api/v1/status",
                expected_status=[200],
                validation_func=self.validate_status_response,
                description="Check system status and health"
            ),
            TestCase(
                name="Services Status",
                method="GET",
                endpoint="/api/v1/services/status",
                expected_status=[200, 404],  # Might not exist on all systems
                validation_func=self.validate_json_response,
                description="Check status of PacketFence services"
            ),
        ])
        
        # Configuration Tests
        test_cases.extend([
            TestCase(
                name="Get Configuration",
                method="GET",
                endpoint="/api/v1/config",
                expected_status=[200],
                validation_func=self.validate_config_response,
                description="Retrieve system configuration"
            ),
            TestCase(
                name="Get Authentication Sources",
                method="GET",
                endpoint="/api/v1/config/sources",
                expected_status=[200, 404],
                validation_func=self.validate_json_response,
                description="Get configured authentication sources"
            ),
            TestCase(
                name="Get Network Switches",
                method="GET",
                endpoint="/api/v1/config/switches",
                expected_status=[200, 404],
                validation_func=self.validate_json_response,
                description="Get network switches configuration"
            ),
            TestCase(
                name="Get DHCP Options",
                method="GET",
                endpoint="/api/v1/dhcp_options",
                expected_status=[200, 404],
                validation_func=self.validate_json_response,
                description="Get DHCP options configuration"
            ),
        ])
        
        # Reporting Tests
        test_cases.extend([
            TestCase(
                name="List Reports",
                method="GET",
                endpoint="/api/v1.1/reports",
                expected_status=[200],
                validation_func=self.validate_list_response,
                description="List available dynamic reports"
            ),
        ])
        
        # Data Management Tests (Read-Only)
        test_cases.extend([
            TestCase(
                name="List Nodes",
                method="GET",
                endpoint="/api/v1/nodes",
                expected_status=[200],
                validation_func=self.validate_list_response,
                description="List network nodes/devices"
            ),
            TestCase(
                name="List Nodes (Limited)",
                method="GET",
                endpoint="/api/v1/nodes?limit=5",
                expected_status=[200],
                validation_func=self.validate_list_response,
                description="List nodes with pagination limit"
            ),
            TestCase(
                name="List Users",
                method="GET",
                endpoint="/api/v1/users",
                expected_status=[200],
                validation_func=self.validate_list_response,
                description="List registered users"
            ),
            TestCase(
                name="List Users (Limited)",
                method="GET",
                endpoint="/api/v1/users?limit=5",
                expected_status=[200],
                validation_func=self.validate_list_response,
                description="List users with pagination limit"
            ),
            TestCase(
                name="List Violations",
                method="GET",
                endpoint="/api/v1/violations",
                expected_status=[200],
                validation_func=self.validate_list_response,
                description="List security violations"
            ),
        ])
        
        # Search Tests
        test_cases.extend([
            TestCase(
                name="Search Nodes",
                method="POST",
                endpoint="/api/v1/nodes/search",
                data={"query": {"limit": 5}},
                expected_status=[200, 422],  # 422 if search syntax is invalid
                validation_func=self.validate_list_response,
                description="Search nodes with query parameters"
            ),
            TestCase(
                name="Search Users",
                method="POST",
                endpoint="/api/v1/users/search",
                data={"query": {"limit": 5}},
                expected_status=[200, 422],
                validation_func=self.validate_list_response,
                description="Search users with query parameters"
            ),
        ])
        
        # Options Tests (for CORS and API discovery)
        test_cases.extend([
            TestCase(
                name="Options - Nodes",
                method="OPTIONS",
                endpoint="/api/v1/nodes",
                expected_status=[200, 204, 405],  # 405 if OPTIONS not supported
                description="Get allowed methods for nodes endpoint"
            ),
            TestCase(
                name="Options - Users",
                method="OPTIONS",
                endpoint="/api/v1/users",
                expected_status=[200, 204, 405],
                description="Get allowed methods for users endpoint"
            ),
        ])
        
        return test_cases
    
    def run_test_case(self, test_case: TestCase) -> Dict[str, Any]:
        """Execute a single test case"""
        print(f"  Running: {test_case.name}")
        
        start_time = time.time()
        
        try:
            # Make the API request
            if test_case.method.upper() == "GET":
                response = self.client.get(test_case.endpoint)
            elif test_case.method.upper() == "POST":
                response = self.client.post(test_case.endpoint, json_data=test_case.data)
            elif test_case.method.upper() == "PUT":
                response = self.client.put(test_case.endpoint, json_data=test_case.data)
            elif test_case.method.upper() == "DELETE":
                response = self.client.delete(test_case.endpoint)
            elif test_case.method.upper() == "OPTIONS":
                response = self.client.options(test_case.endpoint)
            else:
                raise ValueError(f"Unsupported HTTP method: {test_case.method}")
            
            execution_time = time.time() - start_time
            
            # Check status code
            status_ok = (
                not test_case.expected_status or 
                response.status_code in test_case.expected_status
            )
            
            # Run validation function if provided
            validation_ok = True
            validation_message = ""
            if test_case.validation_func and response.success:
                validation_ok, validation_message = test_case.validation_func(response)
            
            # Overall test success
            test_success = status_ok and (not test_case.validation_func or validation_ok)
            
            result = {
                'name': test_case.name,
                'method': test_case.method,
                'endpoint': test_case.endpoint,
                'description': test_case.description,
                'success': test_success,
                'status_code': response.status_code,
                'status_ok': status_ok,
                'validation_ok': validation_ok,
                'validation_message': validation_message,
                'execution_time': execution_time,
                'error': response.error,
                'response_size': len(str(response.data)) if response.data else 0,
                'timestamp': datetime.now().isoformat()
            }
            
            # Print result
            status_icon = "✓" if test_success else "✗"
            status_color = "\033[92m" if test_success else "\033[91m"
            reset_color = "\033[0m"
            
            print(f"    {status_color}{status_icon}{reset_color} {test_case.name} "
                  f"({response.status_code}, {execution_time:.3f}s)")
            
            if not test_success:
                if not status_ok:
                    print(f"      Status: Expected {test_case.expected_status}, got {response.status_code}")
                if not validation_ok:
                    print(f"      Validation: {validation_message}")
                if response.error:
                    print(f"      Error: {response.error}")
            
            return result
            
        except Exception as e:
            execution_time = time.time() - start_time
            error_msg = f"Test execution failed: {str(e)}"
            
            result = {
                'name': test_case.name,
                'method': test_case.method,
                'endpoint': test_case.endpoint,
                'description': test_case.description,
                'success': False,
                'status_code': 0,
                'status_ok': False,
                'validation_ok': False,
                'validation_message': "",
                'execution_time': execution_time,
                'error': error_msg,
                'response_size': 0,
                'timestamp': datetime.now().isoformat()
            }
            
            print(f"    \033[91m✗\033[0m {test_case.name} - {error_msg}")
            return result
    
    def run_all_tests(self) -> Dict[str, Any]:
        """Run all test cases and return comprehensive results"""
        print("\n🧪 Running PacketFence API Test Suite")
        print("=" * 60)
        
        # Generate test cases
        test_cases = self.generate_test_cases()
        
        # Run tests
        passed = 0
        failed = 0
        total_time = 0
        
        for i, test_case in enumerate(test_cases, 1):
            print(f"\n[{i}/{len(test_cases)}] {test_case.description}")
            
            result = self.run_test_case(test_case)
            self.test_results.append(result)
            
            if result['success']:
                passed += 1
            else:
                failed += 1
            
            total_time += result['execution_time']
            
            # Small delay to avoid overwhelming the server
            if self.config.get('testing', {}).get('delay_between_requests', 0) > 0:
                time.sleep(self.config['testing']['delay_between_requests'])
        
        # Generate summary
        summary = {
            'total_tests': len(test_cases),
            'passed': passed,
            'failed': failed,
            'success_rate': (passed / len(test_cases)) * 100,
            'total_execution_time': total_time,
            'average_response_time': total_time / len(test_cases),
            'timestamp': datetime.now().isoformat(),
            'test_results': self.test_results
        }
        
        self.print_summary(summary)
        return summary
    
    def print_summary(self, summary: Dict[str, Any]):
        """Print test execution summary"""
        print("\n" + "=" * 60)
        print("📊 Test Execution Summary")
        print("=" * 60)
        
        # Overall stats
        print(f"Total Tests:     {summary['total_tests']}")
        print(f"Passed:          \033[92m{summary['passed']}\033[0m")
        print(f"Failed:          \033[91m{summary['failed']}\033[0m")
        print(f"Success Rate:    {summary['success_rate']:.1f}%")
        print(f"Total Time:      {summary['total_execution_time']:.3f}s")
        print(f"Average Time:    {summary['average_response_time']:.3f}s")
        
        # Failed tests details
        if summary['failed'] > 0:
            print(f"\n\033[91m❌ Failed Tests:\033[0m")
            for result in summary['test_results']:
                if not result['success']:
                    print(f"  • {result['name']} ({result['method']} {result['endpoint']})")
                    if result['error']:
                        print(f"    Error: {result['error']}")
        
        # Performance insights
        slow_tests = [r for r in summary['test_results'] if r['execution_time'] > 2.0]
        if slow_tests:
            print(f"\n⚠️  Slow Tests (>2s):")
            for result in slow_tests:
                print(f"  • {result['name']}: {result['execution_time']:.3f}s")
    
    def save_results(self, filename: str = None):
        """Save test results to file"""
        if not filename:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"pf_api_test_results_{timestamp}.json"
        
        summary = {
            'total_tests': len(self.test_results),
            'passed': sum(1 for r in self.test_results if r['success']),
            'failed': sum(1 for r in self.test_results if not r['success']),
            'timestamp': datetime.now().isoformat(),
            'test_results': self.test_results
        }
        
        with open(filename, 'w') as f:
            json.dump(summary, f, indent=2, ensure_ascii=False)
        
        print(f"\n💾 Test results saved to: {filename}")
        return filename


def main():
    """Main entry point for the test suite"""
    parser = argparse.ArgumentParser(description="PacketFence API Automated Test Suite")
    
    # Connection options
    parser.add_argument('--url', default='https://localhost:9999', 
                       help='PacketFence API base URL')
    parser.add_argument('--username', default='admin',
                       help='Username for authentication')
    parser.add_argument('--password', default='admin',
                       help='Password for authentication')
    parser.add_argument('--token', help='Bearer token for authentication')
    parser.add_argument('--no-ssl-verify', action='store_true',
                       help='Disable SSL verification')
    
    # Test options
    parser.add_argument('--config', help='Configuration file')
    parser.add_argument('--save-results', default=True, action='store_true',
                       help='Save test results to file')
    parser.add_argument('--output', help='Output file for results')
    parser.add_argument('--delay', type=float, default=0.1,
                       help='Delay between requests in seconds')
    
    args = parser.parse_args()
    
    # Initialize client
    print(f"🔗 Connecting to PacketFence API at {args.url}")
    
    client = PacketFenceAPIClient(
        base_url=args.url,
        username=args.username if not args.token else None,
        password=args.password if not args.token else None,
        token=args.token,
        verify_ssl=not args.no_ssl_verify,
        timeout=30
    )
    
    # Test connection
    response = client.test_connection()
    if not response.success:
        print(f"\033[91m❌ Failed to connect to PacketFence API: {response.error}\033[0m")
        sys.exit(1)
    
    print(f"\033[92m✓ Successfully connected to PacketFence API\033[0m")
    
    # Load configuration
    config = {
        'testing': {
            'delay_between_requests': args.delay
        }
    }
    
    if args.config and os.path.exists(args.config):
        with open(args.config, 'r') as f:
            if args.config.endswith('.yaml') or args.config.endswith('.yml'):
                import yaml
                config.update(yaml.safe_load(f))
            else:
                config.update(json.load(f))
    
    # Run test suite
    test_suite = PacketFenceTestSuite(client, config)
    results = test_suite.run_all_tests()
    
    # Save results
    if args.save_results:
        test_suite.save_results(args.output)
    
    # Exit with error code if tests failed
    if results['failed'] > 0:
        sys.exit(1)


if __name__ == '__main__':
    main()