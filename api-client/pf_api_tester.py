#!/usr/bin/env python3
"""
PacketFence API Testing CLI

Command-line interface for testing PacketFence API endpoints interactively
or through batch operations.
"""

import argparse
import json
import sys
import os
from pathlib import Path
from typing import Dict, Any, List
import yaml
from datetime import datetime
import csv
from tabulate import tabulate
import colorama
from colorama import Fore, Style, Back

# Add the current directory to the path to import our client
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from packetfence_client import PacketFenceAPIClient, APIResponse

colorama.init()


class PacketFenceAPITester:
    """Interactive CLI for testing PacketFence API endpoints"""
    
    def __init__(self, config_file: str = None):
        """Initialize the API tester with optional configuration file"""
        self.config = self.load_config(config_file)
        self.client = None
        self.test_results = []
        
    def load_config(self, config_file: str = None) -> Dict:
        """Load configuration from file"""
        default_config = {
            'server': {
                'base_url': 'https://localhost:9999',
                'verify_ssl': False,
                'timeout': 30
            },
            'auth': {
                'username': 'admin',
                'password': 'admin'
            },
            'testing': {
                'max_retries': 3,
                'save_results': True,
                'results_format': 'json'
            }
        }
        
        if config_file and os.path.exists(config_file):
            try:
                with open(config_file, 'r') as f:
                    if config_file.endswith('.yaml') or config_file.endswith('.yml'):
                        loaded_config = yaml.safe_load(f)
                    else:
                        loaded_config = json.load(f)
                
                # Merge with defaults
                for section, values in loaded_config.items():
                    if section in default_config:
                        default_config[section].update(values)
                    else:
                        default_config[section] = values
                        
                print(f"{Fore.GREEN}✓ Loaded configuration from {config_file}{Style.RESET_ALL}")
            except Exception as e:
                print(f"{Fore.YELLOW}⚠ Failed to load config from {config_file}: {e}{Style.RESET_ALL}")
                print(f"{Fore.YELLOW}  Using default configuration{Style.RESET_ALL}")
        
        return default_config
    
    def connect(self, base_url: str = None, username: str = None, password: str = None, token: str = None):
        """Establish connection to PacketFence API"""
        # Use provided parameters or fall back to config
        api_url = base_url or self.config['server']['base_url']
        api_username = username or self.config['auth'].get('username')
        api_password = password or self.config['auth'].get('password')
        api_token = token or self.config['auth'].get('token')
        
        self.client = PacketFenceAPIClient(
            base_url=api_url,
            username=api_username,
            password=api_password,
            token=api_token,
            verify_ssl=self.config['server']['verify_ssl'],
            timeout=self.config['server']['timeout'],
            max_retries=self.config['testing']['max_retries']
        )
        
        print(f"{Fore.CYAN}🔗 Connecting to PacketFence API at {api_url}{Style.RESET_ALL}")
        
        # Test connection
        response = self.client.test_connection()
        if response.success:
            print(f"{Fore.GREEN}✓ Successfully connected to PacketFence API{Style.RESET_ALL}")
            print(f"  Server response time: {response.execution_time:.3f}s")
        else:
            print(f"{Fore.RED}✗ Failed to connect: {response.error}{Style.RESET_ALL}")
            return False
        
        return True
    
    def print_response(self, response: APIResponse, endpoint: str = None):
        """Pretty print API response"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        
        if response.success:
            status_color = Fore.GREEN
            status_icon = "✓"
        else:
            status_color = Fore.RED
            status_icon = "✗"
        
        print(f"\n{status_color}{status_icon} [{timestamp}] {endpoint or 'API Call'}{Style.RESET_ALL}")
        print(f"   Status: {status_color}{response.status_code}{Style.RESET_ALL}")
        print(f"   Time: {response.execution_time:.3f}s")
        
        if response.error:
            print(f"   Error: {Fore.RED}{response.error}{Style.RESET_ALL}")
        
        if response.data:
            print(f"   Response:")
            try:
                formatted_json = json.dumps(response.data, indent=2, ensure_ascii=False)
                # Limit output size for readability
                if len(formatted_json) > 2000:
                    lines = formatted_json.split('\n')
                    truncated = '\n'.join(lines[:20]) + f"\n   ... ({len(lines)-20} more lines) ..."
                    print(f"   {Fore.CYAN}{truncated}{Style.RESET_ALL}")
                else:
                    print(f"   {Fore.CYAN}{formatted_json}{Style.RESET_ALL}")
            except:
                print(f"   {Fore.CYAN}{str(response.data)[:500]}{Style.RESET_ALL}")
    
    def interactive_mode(self):
        """Start interactive mode for manual testing"""
        print(f"\n{Fore.MAGENTA}🔧 PacketFence API Interactive Testing Mode{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}Type 'help' for available commands, 'quit' to exit{Style.RESET_ALL}")
        
        if not self.client:
            print(f"{Fore.RED}No API connection established. Use 'connect' command first.{Style.RESET_ALL}")
        
        while True:
            try:
                command = input(f"\n{Fore.BLUE}pf-api> {Style.RESET_ALL}").strip()
                
                if command.lower() in ['quit', 'exit', 'q']:
                    print(f"{Fore.YELLOW}Goodbye!{Style.RESET_ALL}")
                    break
                elif command.lower() in ['help', 'h']:
                    self.print_help()
                elif command.lower().startswith('connect'):
                    parts = command.split()
                    if len(parts) >= 2:
                        self.connect(base_url=parts[1])
                    else:
                        self.connect()
                elif command.lower() == 'endpoints':
                    if self.client:
                        self.client.print_endpoints()
                    else:
                        print(f"{Fore.RED}Not connected. Use 'connect' first.{Style.RESET_ALL}")
                elif command.lower() == 'status':
                    if self.client:
                        response = self.client.test_connection()
                        self.print_response(response, "GET /api/v1/status")
                    else:
                        print(f"{Fore.RED}Not connected. Use 'connect' first.{Style.RESET_ALL}")
                elif command.lower().startswith('get '):
                    if self.client:
                        endpoint = command[4:].strip()
                        response = self.client.get(endpoint)
                        self.print_response(response, f"GET {endpoint}")
                    else:
                        print(f"{Fore.RED}Not connected. Use 'connect' first.{Style.RESET_ALL}")
                elif command.lower().startswith('post '):
                    if self.client:
                        parts = command[5:].strip().split(' ', 1)
                        endpoint = parts[0]
                        data = json.loads(parts[1]) if len(parts) > 1 else {}
                        response = self.client.post(endpoint, json_data=data)
                        self.print_response(response, f"POST {endpoint}")
                    else:
                        print(f"{Fore.RED}Not connected. Use 'connect' first.{Style.RESET_ALL}")
                elif command.lower() == 'test-all':
                    if self.client:
                        self.run_comprehensive_test()
                    else:
                        print(f"{Fore.RED}Not connected. Use 'connect' first.{Style.RESET_ALL}")
                elif command.lower() == 'test-basic':
                    if self.client:
                        self.run_basic_test()
                    else:
                        print(f"{Fore.RED}Not connected. Use 'connect' first.{Style.RESET_ALL}")
                elif command.strip() == '':
                    continue
                else:
                    print(f"{Fore.RED}Unknown command: {command}{Style.RESET_ALL}")
                    print(f"{Fore.YELLOW}Type 'help' for available commands{Style.RESET_ALL}")
                    
            except KeyboardInterrupt:
                print(f"\n{Fore.YELLOW}Use 'quit' to exit{Style.RESET_ALL}")
            except Exception as e:
                print(f"{Fore.RED}Error: {e}{Style.RESET_ALL}")
    
    def print_help(self):
        """Print help information"""
        help_text = f"""
{Fore.CYAN}PacketFence API Tester Commands:{Style.RESET_ALL}

{Fore.GREEN}Connection Commands:{Style.RESET_ALL}
  connect [url]          - Connect to PacketFence API (use config if no URL)
  status                 - Test connection and get server status

{Fore.GREEN}Information Commands:{Style.RESET_ALL}
  endpoints              - List all available API endpoints
  help, h                - Show this help message

{Fore.GREEN}Testing Commands:{Style.RESET_ALL}
  get <endpoint>         - Make GET request to endpoint
  post <endpoint> <json> - Make POST request with JSON data
  test-basic             - Run basic connectivity tests
  test-all               - Run comprehensive test suite

{Fore.GREEN}General:{Style.RESET_ALL}
  quit, exit, q          - Exit the program

{Fore.YELLOW}Examples:{Style.RESET_ALL}
  get /api/v1/nodes
  post /api/v1/nodes/search {{"mac": "aa:bb:cc:dd:ee:ff"}}
  connect https://pf.example.com:9999
"""
        print(help_text)
    
    def run_basic_test(self):
        """Run basic connectivity and authentication tests"""
        print(f"\n{Fore.MAGENTA}🧪 Running Basic API Tests{Style.RESET_ALL}")
        
        tests = [
            ("System Status", lambda: self.client.test_connection()),
            ("Get Reports", lambda: self.client.get_reports()),
            ("Get Services Status", lambda: self.client.get_services_status()),
            ("Get Configuration", lambda: self.client.get_config()),
        ]
        
        passed = 0
        total = len(tests)
        
        for test_name, test_func in tests:
            print(f"\n{Fore.BLUE}Running: {test_name}{Style.RESET_ALL}")
            try:
                response = test_func()
                self.print_response(response, test_name)
                if response.success:
                    passed += 1
                self.test_results.append({
                    'test': test_name,
                    'success': response.success,
                    'status_code': response.status_code,
                    'execution_time': response.execution_time,
                    'error': response.error
                })
            except Exception as e:
                print(f"{Fore.RED}Test failed with exception: {e}{Style.RESET_ALL}")
                self.test_results.append({
                    'test': test_name,
                    'success': False,
                    'status_code': 0,
                    'execution_time': 0,
                    'error': str(e)
                })
        
        print(f"\n{Fore.MAGENTA}📊 Test Results: {passed}/{total} passed{Style.RESET_ALL}")
        
        if self.config['testing']['save_results']:
            self.save_results()
    
    def run_comprehensive_test(self):
        """Run comprehensive test of all major API endpoints"""
        print(f"\n{Fore.MAGENTA}🧪 Running Comprehensive API Test Suite{Style.RESET_ALL}")
        
        tests = [
            # System endpoints
            ("System Status", lambda: self.client.test_connection()),
            ("Get Services Status", lambda: self.client.get_services_status()),
            
            # Configuration endpoints
            ("Get Configuration", lambda: self.client.get_config()),
            ("Get Authentication Sources", lambda: self.client.get_auth_sources()),
            ("Get DHCP Options", lambda: self.client.get_dhcp_options()),
            ("Get Switches", lambda: self.client.get_switches()),
            
            # Reporting endpoints
            ("Get Reports", lambda: self.client.get_reports()),
            
            # Data endpoints (read-only to avoid side effects)
            ("Get Nodes", lambda: self.client.get_nodes(limit=5)),
            ("Get Users", lambda: self.client.get_users(limit=5)),
            ("Get Violations", lambda: self.client.get_violations(limit=5)),
        ]
        
        passed = 0
        total = len(tests)
        
        for test_name, test_func in tests:
            print(f"\n{Fore.BLUE}Running: {test_name}{Style.RESET_ALL}")
            try:
                response = test_func()
                self.print_response(response, test_name)
                if response.success:
                    passed += 1
                self.test_results.append({
                    'test': test_name,
                    'success': response.success,
                    'status_code': response.status_code,
                    'execution_time': response.execution_time,
                    'error': response.error
                })
            except Exception as e:
                print(f"{Fore.RED}Test failed with exception: {e}{Style.RESET_ALL}")
                self.test_results.append({
                    'test': test_name,
                    'success': False,
                    'status_code': 0,
                    'execution_time': 0,
                    'error': str(e)
                })
        
        print(f"\n{Fore.MAGENTA}📊 Test Results: {passed}/{total} passed{Style.RESET_ALL}")
        
        # Print summary table
        if self.test_results:
            self.print_results_table()
        
        if self.config['testing']['save_results']:
            self.save_results()
    
    def print_results_table(self):
        """Print test results in a formatted table"""
        print(f"\n{Fore.CYAN}📋 Detailed Test Results:{Style.RESET_ALL}")
        
        headers = ["Test", "Status", "Code", "Time (s)", "Error"]
        rows = []
        
        for result in self.test_results:
            status = f"{Fore.GREEN}PASS{Style.RESET_ALL}" if result['success'] else f"{Fore.RED}FAIL{Style.RESET_ALL}"
            error = (result['error'][:50] + '...') if result['error'] and len(result['error']) > 50 else (result['error'] or '')
            
            rows.append([
                result['test'][:30],
                status,
                result['status_code'],
                f"{result['execution_time']:.3f}",
                error
            ])
        
        print(tabulate(rows, headers=headers, tablefmt="grid"))
    
    def save_results(self):
        """Save test results to file"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        if self.config['testing']['results_format'] == 'json':
            filename = f"pf_api_test_results_{timestamp}.json"
            with open(filename, 'w') as f:
                json.dump({
                    'timestamp': datetime.now().isoformat(),
                    'server': self.config['server']['base_url'],
                    'results': self.test_results
                }, f, indent=2)
        else:
            filename = f"pf_api_test_results_{timestamp}.csv"
            with open(filename, 'w', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=['test', 'success', 'status_code', 'execution_time', 'error'])
                writer.writeheader()
                writer.writerows(self.test_results)
        
        print(f"{Fore.GREEN}✓ Test results saved to {filename}{Style.RESET_ALL}")


def main():
    """Main CLI entry point"""
    parser = argparse.ArgumentParser(
        description="PacketFence API Testing Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Interactive mode with default config
  python pf_api_tester.py --interactive

  # Connect to specific server and run tests
  python pf_api_tester.py --url https://pf.example.com:9999 --username admin --password secret --test-basic

  # Run comprehensive test suite
  python pf_api_tester.py --config config.yaml --test-all

  # Custom endpoint testing
  python pf_api_tester.py --url https://localhost:9999 --get /api/v1/nodes
        """
    )
    
    # Connection options
    parser.add_argument('--url', help='PacketFence API base URL')
    parser.add_argument('--username', help='Username for authentication')
    parser.add_argument('--password', help='Password for authentication')
    parser.add_argument('--token', help='Bearer token for authentication')
    parser.add_argument('--config', help='Configuration file (JSON or YAML)')
    parser.add_argument('--no-ssl-verify', action='store_true', help='Disable SSL verification')
    
    # Testing modes
    parser.add_argument('--interactive', '-i', action='store_true', help='Start interactive mode')
    parser.add_argument('--test-basic', action='store_true', help='Run basic connectivity tests')
    parser.add_argument('--test-all', action='store_true', help='Run comprehensive test suite')
    
    # Individual requests
    parser.add_argument('--get', help='Make GET request to endpoint')
    parser.add_argument('--post', nargs=2, metavar=('ENDPOINT', 'DATA'), help='Make POST request with JSON data')
    
    # Output options
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    parser.add_argument('--quiet', '-q', action='store_true', help='Quiet output')
    
    args = parser.parse_args()
    
    # Initialize tester
    tester = PacketFenceAPITester(config_file=args.config)
    
    # Handle connection
    if args.url or args.username or args.password or args.token:
        if not tester.connect(args.url, args.username, args.password, args.token):
            sys.exit(1)
    elif not args.interactive:
        # Auto-connect with config for non-interactive mode
        if not tester.connect():
            sys.exit(1)
    
    # Execute based on arguments
    if args.interactive:
        tester.interactive_mode()
    elif args.test_basic:
        tester.run_basic_test()
    elif args.test_all:
        tester.run_comprehensive_test()
    elif args.get:
        if not tester.client:
            print("Error: Not connected to API")
            sys.exit(1)
        response = tester.client.get(args.get)
        tester.print_response(response, f"GET {args.get}")
    elif args.post:
        if not tester.client:
            print("Error: Not connected to API")
            sys.exit(1)
        try:
            data = json.loads(args.post[1])
            response = tester.client.post(args.post[0], json_data=data)
            tester.print_response(response, f"POST {args.post[0]}")
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON data: {e}")
            sys.exit(1)
    else:
        # Default to interactive mode
        tester.interactive_mode()


if __name__ == '__main__':
    main()