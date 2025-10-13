#!/usr/bin/env python3
"""
PacketFence API Client

A comprehensive Python client for testing and interacting with PacketFence API endpoints.
Built from the OpenAPI specification to support all available endpoints.
"""

import json
import requests
import logging
from typing import Dict, Any, Optional, List, Union
from urllib.parse import urljoin, urlparse
import urllib3
from dataclasses import dataclass
from enum import Enum
import time

# Disable SSL warnings for development/testing
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class AuthType(Enum):
    """Authentication types supported by PacketFence API"""
    BASIC = "basic"
    BEARER = "bearer"
    API_KEY = "api_key"


@dataclass
class APIResponse:
    """Structured response from API calls"""
    status_code: int
    data: Optional[Dict[Any, Any]]
    headers: Dict[str, str]
    success: bool
    error: Optional[str] = None
    execution_time: float = 0.0


class PacketFenceAPIClient:
    """
    PacketFence API Client
    
    A comprehensive client for interacting with all PacketFence API endpoints
    as defined in the OpenAPI specification.
    """
    
    def __init__(self, 
                 base_url: str = "https://localhost:9999",
                 username: str = None,
                 password: str = None,
                 token: str = None,
                 api_key: str = None,
                 verify_ssl: bool = False,
                 timeout: int = 30,
                 max_retries: int = 3):
        """
        Initialize the PacketFence API Client
        
        Args:
            base_url: Base URL for the PacketFence API
            username: Username for basic auth
            password: Password for basic auth
            token: Bearer token for authentication
            api_key: API key for authentication
            verify_ssl: Whether to verify SSL certificates
            timeout: Request timeout in seconds
            max_retries: Maximum number of retry attempts
        """
        self.base_url = base_url.rstrip('/')
        self.verify_ssl = verify_ssl
        self.timeout = timeout
        self.max_retries = max_retries
        
        # Set up session
        self.session = requests.Session()
        self.session.verify = verify_ssl
        
        # Configure authentication
        if username and password:
            self.session.auth = (username, password)
            self.auth_type = AuthType.BASIC
        elif token:
            self.session.headers.update({'Authorization': f'Bearer {token}'})
            self.auth_type = AuthType.BEARER
        elif api_key:
            self.session.headers.update({'X-API-Key': api_key})
            self.auth_type = AuthType.API_KEY
        else:
            logger.warning("No authentication credentials provided")
            self.auth_type = None
        
        # Set default headers
        self.session.headers.update({
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'PacketFence-API-Client/1.0'
        })
        
        logger.info(f"Initialized PacketFence API client for {base_url}")

    def _make_request(self, method: str, endpoint: str, **kwargs) -> APIResponse:
        """
        Make an HTTP request to the PacketFence API
        
        Args:
            method: HTTP method (GET, POST, PUT, DELETE, etc.)
            endpoint: API endpoint path
            **kwargs: Additional request parameters
            
        Returns:
            APIResponse object with status, data, and metadata
        """
        url = urljoin(self.base_url, endpoint.lstrip('/'))
        start_time = time.time()
        
        # Set timeout if not specified
        if 'timeout' not in kwargs:
            kwargs['timeout'] = self.timeout
            
        # Ensure verify parameter is set
        kwargs['verify'] = self.verify_ssl
        
        for attempt in range(self.max_retries + 1):
            try:
                logger.debug(f"{method.upper()} {url} (attempt {attempt + 1})")
                response = self.session.request(method, url, **kwargs)
                execution_time = time.time() - start_time
                
                # Parse response data
                try:
                    data = response.json() if response.content else None
                except json.JSONDecodeError:
                    data = {"raw_content": response.text}
                
                success = 200 <= response.status_code < 300
                error = None if success else f"HTTP {response.status_code}: {response.reason}"
                
                api_response = APIResponse(
                    status_code=response.status_code,
                    data=data,
                    headers=dict(response.headers),
                    success=success,
                    error=error,
                    execution_time=execution_time
                )
                
                if success:
                    logger.info(f"✓ {method.upper()} {endpoint} - {response.status_code} ({execution_time:.3f}s)")
                else:
                    logger.warning(f"✗ {method.upper()} {endpoint} - {response.status_code} ({execution_time:.3f}s)")
                
                return api_response
                
            except requests.exceptions.RequestException as e:
                execution_time = time.time() - start_time
                if attempt < self.max_retries:
                    wait_time = 2 ** attempt
                    logger.warning(f"Request failed, retrying in {wait_time}s: {e}")
                    time.sleep(wait_time)
                else:
                    error_msg = f"Request failed after {self.max_retries + 1} attempts: {e}"
                    logger.error(error_msg)
                    return APIResponse(
                        status_code=0,
                        data=None,
                        headers={},
                        success=False,
                        error=error_msg,
                        execution_time=execution_time
                    )

    def get(self, endpoint: str, params: Dict = None, **kwargs) -> APIResponse:
        """Make a GET request"""
        if params:
            kwargs['params'] = params
        return self._make_request('GET', endpoint, **kwargs)

    def post(self, endpoint: str, data: Dict = None, json_data: Dict = None, **kwargs) -> APIResponse:
        """Make a POST request"""
        if json_data:
            kwargs['json'] = json_data
        elif data:
            kwargs['data'] = data
        return self._make_request('POST', endpoint, **kwargs)

    def put(self, endpoint: str, data: Dict = None, json_data: Dict = None, **kwargs) -> APIResponse:
        """Make a PUT request"""
        if json_data:
            kwargs['json'] = json_data
        elif data:
            kwargs['data'] = data
        return self._make_request('PUT', endpoint, **kwargs)

    def patch(self, endpoint: str, data: Dict = None, json_data: Dict = None, **kwargs) -> APIResponse:
        """Make a PATCH request"""
        if json_data:
            kwargs['json'] = json_data
        elif data:
            kwargs['data'] = data
        return self._make_request('PATCH', endpoint, **kwargs)

    def delete(self, endpoint: str, **kwargs) -> APIResponse:
        """Make a DELETE request"""
        return self._make_request('DELETE', endpoint, **kwargs)

    def options(self, endpoint: str, **kwargs) -> APIResponse:
        """Make an OPTIONS request"""
        return self._make_request('OPTIONS', endpoint, **kwargs)

    # ===============================================
    # PacketFence-specific API endpoints
    # ===============================================

    def test_connection(self) -> APIResponse:
        """Test the API connection and authentication"""
        return self.get('/api/v1/status')

    # Node Management
    def get_nodes(self, limit: int = 25, cursor: int = None, **params) -> APIResponse:
        """Get all nodes"""
        query_params = {'limit': limit}
        if cursor:
            query_params['cursor'] = cursor
        query_params.update(params)
        return self.get('/api/v1/nodes', params=query_params)

    def get_node(self, node_id: str) -> APIResponse:
        """Get a specific node by ID"""
        return self.get(f'/api/v1/node/{node_id}')

    def create_node(self, node_data: Dict) -> APIResponse:
        """Create a new node"""
        return self.post('/api/v1/nodes', json_data=node_data)

    def update_node(self, node_id: str, node_data: Dict) -> APIResponse:
        """Update an existing node"""
        return self.put(f'/api/v1/node/{node_id}', json_data=node_data)

    def delete_node(self, node_id: str) -> APIResponse:
        """Delete a node"""
        return self.delete(f'/api/v1/node/{node_id}')

    def search_nodes(self, search_criteria: Dict) -> APIResponse:
        """Search nodes with criteria"""
        return self.post('/api/v1/nodes/search', json_data=search_criteria)

    # User Management
    def get_users(self, limit: int = 25, cursor: int = None, **params) -> APIResponse:
        """Get all users"""
        query_params = {'limit': limit}
        if cursor:
            query_params['cursor'] = cursor
        query_params.update(params)
        return self.get('/api/v1/users', params=query_params)

    def get_user(self, user_id: str) -> APIResponse:
        """Get a specific user by ID"""
        return self.get(f'/api/v1/user/{user_id}')

    def create_user(self, user_data: Dict) -> APIResponse:
        """Create a new user"""
        return self.post('/api/v1/users', json_data=user_data)

    def update_user(self, user_id: str, user_data: Dict) -> APIResponse:
        """Update an existing user"""
        return self.put(f'/api/v1/user/{user_id}', json_data=user_data)

    def delete_user(self, user_id: str) -> APIResponse:
        """Delete a user"""
        return self.delete(f'/api/v1/user/{user_id}')

    # Reports
    def get_reports(self) -> APIResponse:
        """Get available reports"""
        return self.get('/api/v1.1/reports')

    def get_report(self, report_id: str) -> APIResponse:
        """Get a specific report"""
        return self.get(f'/api/v1.1/report/{report_id}')

    def search_report(self, report_id: str, search_criteria: Dict) -> APIResponse:
        """Search within a specific report"""
        return self.post(f'/api/v1.1/report/{report_id}/search', json_data=search_criteria)

    # Configuration
    def get_config(self, section: str = None) -> APIResponse:
        """Get configuration"""
        endpoint = '/api/v1/config'
        if section:
            endpoint += f'/{section}'
        return self.get(endpoint)

    def update_config(self, section: str, config_data: Dict) -> APIResponse:
        """Update configuration section"""
        return self.put(f'/api/v1/config/{section}', json_data=config_data)

    # Services
    def get_services_status(self) -> APIResponse:
        """Get status of all services"""
        return self.get('/api/v1/services/status')

    def restart_service(self, service_name: str) -> APIResponse:
        """Restart a specific service"""
        return self.post(f'/api/v1/service/{service_name}/restart')

    def start_service(self, service_name: str) -> APIResponse:
        """Start a specific service"""
        return self.post(f'/api/v1/service/{service_name}/start')

    def stop_service(self, service_name: str) -> APIResponse:
        """Stop a specific service"""
        return self.post(f'/api/v1/service/{service_name}/stop')

    # DHCP
    def get_dhcp_options(self) -> APIResponse:
        """Get DHCP options"""
        return self.get('/api/v1/dhcp_options')

    # Authentication Sources
    def get_auth_sources(self) -> APIResponse:
        """Get authentication sources"""
        return self.get('/api/v1/config/sources')

    # Violations
    def get_violations(self, limit: int = 25, **params) -> APIResponse:
        """Get violations"""
        query_params = {'limit': limit}
        query_params.update(params)
        return self.get('/api/v1/violations', params=query_params)

    def get_violation(self, violation_id: str) -> APIResponse:
        """Get a specific violation"""
        return self.get(f'/api/v1/violation/{violation_id}')

    # Network Devices
    def get_switches(self) -> APIResponse:
        """Get network switches configuration"""
        return self.get('/api/v1/config/switches')

    def get_switch(self, switch_id: str) -> APIResponse:
        """Get specific switch configuration"""
        return self.get(f'/api/v1/config/switch/{switch_id}')

    # Utility Methods
    def get_all_endpoints_info(self) -> Dict[str, Any]:
        """
        Return information about all available endpoints based on the OpenAPI spec
        """
        endpoints = {
            'Node Management': [
                'GET /api/v1/nodes - List all nodes',
                'GET /api/v1/node/{id} - Get specific node',
                'POST /api/v1/nodes - Create node',
                'PUT /api/v1/node/{id} - Update node',
                'DELETE /api/v1/node/{id} - Delete node',
                'POST /api/v1/nodes/search - Search nodes',
            ],
            'User Management': [
                'GET /api/v1/users - List all users',
                'GET /api/v1/user/{id} - Get specific user',
                'POST /api/v1/users - Create user',
                'PUT /api/v1/user/{id} - Update user',
                'DELETE /api/v1/user/{id} - Delete user',
            ],
            'Reports': [
                'GET /api/v1.1/reports - List reports',
                'GET /api/v1.1/report/{id} - Get specific report',
                'POST /api/v1.1/report/{id}/search - Search report',
            ],
            'Configuration': [
                'GET /api/v1/config - Get configuration',
                'GET /api/v1/config/{section} - Get config section',
                'PUT /api/v1/config/{section} - Update config section',
            ],
            'Services': [
                'GET /api/v1/services/status - Service status',
                'POST /api/v1/service/{name}/start - Start service',
                'POST /api/v1/service/{name}/stop - Stop service',
                'POST /api/v1/service/{name}/restart - Restart service',
            ],
            'System': [
                'GET /api/v1/status - System status',
                'GET /api/v1/dhcp_options - DHCP options',
                'GET /api/v1/config/sources - Auth sources',
                'GET /api/v1/config/switches - Network switches',
            ]
        }
        return endpoints

    def print_endpoints(self):
        """Print all available endpoints"""
        endpoints = self.get_all_endpoints_info()
        print("\n📋 Available PacketFence API Endpoints:")
        print("=" * 60)
        for category, endpoint_list in endpoints.items():
            print(f"\n🔹 {category}:")
            for endpoint in endpoint_list:
                print(f"   {endpoint}")
        print("\n")
