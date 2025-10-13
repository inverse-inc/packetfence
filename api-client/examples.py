#!/usr/bin/env python3
"""
PacketFence API Client - Usage Examples

This script demonstrates how to use the PacketFence API client
for common operations and testing scenarios.
"""

import sys
import os
import json
from datetime import datetime

# Add the current directory to the path to import our client
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from packetfence_client import PacketFenceAPIClient


def example_basic_connection():
    """Example: Basic connection and status check"""
    print("🔗 Example: Basic Connection and Status Check")
    print("-" * 50)
    
    # Initialize client
    client = PacketFenceAPIClient(
        base_url="https://localhost:9999",
        username="admin",
        password="admin",
        verify_ssl=False  # For development/testing
    )
    
    # Test connection
    print("Testing API connection...")
    response = client.test_connection()
    
    if response.success:
        print(f"✓ Connected successfully! (Response time: {response.execution_time:.3f}s)")
        if response.data:
            print(f"  Server info: {json.dumps(response.data, indent=2)}")
    else:
        print(f"✗ Connection failed: {response.error}")
    
    return client if response.success else None


def example_node_management(client):
    """Example: Node management operations"""
    print("\n📱 Example: Node Management")
    print("-" * 30)
    
    # Get list of nodes
    print("Fetching nodes...")
    nodes = client.get_nodes(limit=5)
    
    if nodes.success and nodes.data:
        items = nodes.data.get('items', [])
        print(f"✓ Found {len(items)} nodes (showing first 5)")
        
        for i, node in enumerate(items[:3], 1):  # Show first 3
            mac = node.get('mac', 'N/A')
            pid = node.get('pid', 'N/A')
            status = node.get('status', 'N/A')
            print(f"  {i}. MAC: {mac}, User: {pid}, Status: {status}")
    else:
        print(f"✗ Failed to get nodes: {nodes.error}")
    
    # Search for a specific node (example)
    print("\nSearching for nodes...")
    search_result = client.search_nodes({
        "query": {"limit": 3}
    })
    
    if search_result.success:
        print(f"✓ Search completed (Response time: {search_result.execution_time:.3f}s)")
    else:
        print(f"✗ Search failed: {search_result.error}")


def example_user_management(client):
    """Example: User management operations"""
    print("\n👥 Example: User Management")
    print("-" * 26)
    
    # Get list of users
    print("Fetching users...")
    users = client.get_users(limit=5)
    
    if users.success and users.data:
        items = users.data.get('items', [])
        print(f"✓ Found {len(items)} users (showing first 5)")
        
        for i, user in enumerate(items[:3], 1):  # Show first 3
            pid = user.get('pid', 'N/A')
            email = user.get('email', 'N/A')
            status = user.get('status', 'N/A')
            print(f"  {i}. PID: {pid}, Email: {email}, Status: {status}")
    else:
        print(f"✗ Failed to get users: {users.error}")


def example_system_info(client):
    """Example: System information retrieval"""
    print("\n⚙️ Example: System Information")
    print("-" * 30)
    
    # Get services status
    print("Checking services status...")
    services = client.get_services_status()
    
    if services.success:
        print(f"✓ Services status retrieved (Response time: {services.execution_time:.3f}s)")
        if services.data and isinstance(services.data, dict):
            print(f"  Found {len(services.data)} service entries")
    else:
        print(f"✗ Failed to get services: {services.error}")
    
    # Get configuration
    print("\nRetrieving configuration...")
    config = client.get_config()
    
    if config.success:
        print(f"✓ Configuration retrieved (Response time: {config.execution_time:.3f}s)")
        if config.data and isinstance(config.data, dict):
            sections = list(config.data.keys())[:5]  # Show first 5 sections
            print(f"  Configuration sections: {', '.join(sections)}...")
    else:
        print(f"✗ Failed to get configuration: {config.error}")


def example_reports(client):
    """Example: Working with reports"""
    print("\n📊 Example: Reports")
    print("-" * 17)
    
    # Get available reports
    print("Fetching available reports...")
    reports = client.get_reports()
    
    if reports.success and reports.data:
        if isinstance(reports.data, list):
            print(f"✓ Found {len(reports.data)} available reports")
            for i, report in enumerate(reports.data[:3], 1):  # Show first 3
                if isinstance(report, dict):
                    name = report.get('name', report.get('id', f'Report {i}'))
                    print(f"  {i}. {name}")
        elif isinstance(reports.data, dict):
            print(f"✓ Reports data retrieved")
            if 'items' in reports.data:
                items = reports.data['items']
                print(f"  Found {len(items)} report items")
    else:
        print(f"✗ Failed to get reports: {reports.error}")


def example_performance_monitoring(client):
    """Example: Performance monitoring"""
    print("\n⏱️ Example: Performance Monitoring")
    print("-" * 33)
    
    endpoints_to_test = [
        "/api/v1/status",
        "/api/v1/nodes",
        "/api/v1/users",
        "/api/v1/violations"
    ]
    
    results = []
    
    for endpoint in endpoints_to_test:
        print(f"Testing {endpoint}...")
        response = client.get(endpoint + "?limit=1")  # Limit for faster response
        
        results.append({
            'endpoint': endpoint,
            'status_code': response.status_code,
            'success': response.success,
            'execution_time': response.execution_time
        })
        
        status_icon = "✓" if response.success else "✗"
        print(f"  {status_icon} {response.status_code} - {response.execution_time:.3f}s")
    
    # Performance summary
    successful_requests = [r for r in results if r['success']]
    if successful_requests:
        avg_time = sum(r['execution_time'] for r in successful_requests) / len(successful_requests)
        fastest = min(successful_requests, key=lambda x: x['execution_time'])
        slowest = max(successful_requests, key=lambda x: x['execution_time'])
        
        print(f"\n📈 Performance Summary:")
        print(f"  Average response time: {avg_time:.3f}s")
        print(f"  Fastest endpoint: {fastest['endpoint']} ({fastest['execution_time']:.3f}s)")
        print(f"  Slowest endpoint: {slowest['endpoint']} ({slowest['execution_time']:.3f}s)")


def example_error_handling(client):
    """Example: Error handling and validation"""
    print("\n🚨 Example: Error Handling")
    print("-" * 25)
    
    # Test with non-existent endpoint
    print("Testing non-existent endpoint...")
    response = client.get("/api/v1/nonexistent")
    
    if response.success:
        print("✓ Unexpected success (endpoint might exist)")
    else:
        print(f"✗ Expected error: {response.status_code} - {response.error}")
    
    # Test with invalid node ID
    print("\nTesting invalid node lookup...")
    response = client.get_node("invalid-mac-address")
    
    if response.success:
        print("✓ Unexpected success")
    else:
        print(f"✗ Expected error: {response.status_code} - {response.error}")
    
    print("\n💡 Tip: Always check response.success before using response.data")


def run_all_examples():
    """Run all examples in sequence"""
    print("🎯 PacketFence API Client - Usage Examples")
    print("=" * 50)
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Basic connection
    client = example_basic_connection()
    
    if not client:
        print("\n❌ Cannot proceed without a valid connection.")
        print("💡 Make sure PacketFence is running and accessible at the configured URL.")
        print("💡 Check your credentials and network connectivity.")
        return False
    
    # Run all other examples
    try:
        example_system_info(client)
        example_node_management(client)
        example_user_management(client)
        example_reports(client)
        example_performance_monitoring(client)
        example_error_handling(client)
        
        print(f"\n🎉 All examples completed successfully!")
        print("\n📚 Next Steps:")
        print("  1. Modify the connection parameters above for your environment")
        print("  2. Explore the interactive CLI: python pf_api_tester.py --interactive")
        print("  3. Run comprehensive tests: python automated_test_suite.py")
        print("  4. Read README.md for detailed documentation")
        
        return True
        
    except KeyboardInterrupt:
        print("\n\n⚠️ Examples interrupted by user")
        return False
    except Exception as e:
        print(f"\n\n❌ Unexpected error during examples: {e}")
        return False


def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description="PacketFence API Client Examples")
    parser.add_argument('--url', default='https://localhost:9999',
                       help='PacketFence API base URL')
    parser.add_argument('--username', default='admin',
                       help='Username for authentication')
    parser.add_argument('--password', default='admin',
                       help='Password for authentication')
    parser.add_argument('--no-ssl-verify', action='store_true',
                       help='Disable SSL verification')
    
    args = parser.parse_args()
    
    # Update connection parameters for examples
    global example_basic_connection
    original_func = example_basic_connection
    
    def example_basic_connection():
        """Modified basic connection with CLI args"""
        print("🔗 Example: Basic Connection and Status Check")
        print("-" * 50)
        
        # Initialize client with provided parameters
        client = PacketFenceAPIClient(
            base_url=args.url,
            username=args.username,
            password=args.password,
            verify_ssl=not args.no_ssl_verify
        )
        
        # Test connection
        print(f"Testing API connection to {args.url}...")
        response = client.test_connection()
        
        if response.success:
            print(f"✓ Connected successfully! (Response time: {response.execution_time:.3f}s)")
            if response.data:
                # Limit output for readability
                data_str = json.dumps(response.data, indent=2)
                if len(data_str) > 500:
                    data_str = data_str[:500] + "\n  ... (truncated)"
                print(f"  Server info: {data_str}")
        else:
            print(f"✗ Connection failed: {response.error}")
        
        return client if response.success else None
    
    # Run examples
    success = run_all_examples()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()