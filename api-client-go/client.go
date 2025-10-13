// Package pfclient provides a comprehensive Go client for the PacketFence APIpackage apiclientgo

package pfclient

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// AuthType represents the authentication method
type AuthType int

const (
	AuthTypeBasic AuthType = iota
	AuthTypeBearer
	AuthTypeAPIKey
)

// Config holds the configuration for the PacketFence API client
type Config struct {
	BaseURL     string
	Username    string
	Password    string
	Token       string
	APIKey      string
	VerifySSL   bool
	Timeout     time.Duration
	MaxRetries  int
	UserAgent   string
}

// DefaultConfig returns a default configuration
func DefaultConfig() *Config {
	return &Config{
		BaseURL:    "https://localhost:9999",
		VerifySSL:  false,
		Timeout:    30 * time.Second,
		MaxRetries: 3,
		UserAgent:  "PacketFence-API-Client-Go/1.0",
	}
}

// APIResponse represents a response from the PacketFence API
type APIResponse struct {
	StatusCode    int                    `json:"status_code"`
	Data          map[string]interface{} `json:"data,omitempty"`
	RawData       json.RawMessage        `json:"raw_data,omitempty"`
	Headers       http.Header            `json:"headers"`
	Success       bool                   `json:"success"`
	Error         string                 `json:"error,omitempty"`
	ExecutionTime time.Duration          `json:"execution_time"`
}

// Client represents the PacketFence API client
type Client struct {
	config     *Config
	httpClient *http.Client
	authType   AuthType
	baseURL    *url.URL
}

// NewClient creates a new PacketFence API client
func NewClient(config *Config) (*Client, error) {
	if config == nil {
		config = DefaultConfig()
	}

	baseURL, err := url.Parse(config.BaseURL)
	if err != nil {
		return nil, fmt.Errorf("invalid base URL: %w", err)
	}

	// Configure HTTP client
	transport := &http.Transport{
		TLSClientConfig: &tls.Config{
			InsecureSkipVerify: !config.VerifySSL,
		},
	}

	httpClient := &http.Client{
		Transport: transport,
		Timeout:   config.Timeout,
	}

	client := &Client{
		config:     config,
		httpClient: httpClient,
		baseURL:    baseURL,
	}

	// Determine auth type
	if config.Username != "" && config.Password != "" {
		client.authType = AuthTypeBasic
	} else if config.Token != "" {
		client.authType = AuthTypeBearer
	} else if config.APIKey != "" {
		client.authType = AuthTypeAPIKey
	}

	return client, nil
}

// makeRequest performs an HTTP request to the PacketFence API
func (c *Client) makeRequest(ctx context.Context, method, endpoint string, body interface{}, headers map[string]string) (*APIResponse, error) {
	startTime := time.Now()

	// Build URL
	u, err := url.Parse(endpoint)
	if err != nil {
		return nil, fmt.Errorf("invalid endpoint: %w", err)
	}
	fullURL := c.baseURL.ResolveReference(u)

	// Prepare request body
	var reqBody io.Reader
	if body != nil {
		jsonBody, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal request body: %w", err)
		}
		reqBody = bytes.NewBuffer(jsonBody)
	}

	// Create request
	req, err := http.NewRequestWithContext(ctx, method, fullURL.String(), reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Set headers
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", c.config.UserAgent)

	// Add custom headers
	for key, value := range headers {
		req.Header.Set(key, value)
	}

	// Set authentication
	switch c.authType {
	case AuthTypeBasic:
		req.SetBasicAuth(c.config.Username, c.config.Password)
	case AuthTypeBearer:
		req.Header.Set("Authorization", "Bearer "+c.config.Token)
	case AuthTypeAPIKey:
		req.Header.Set("X-API-Key", c.config.APIKey)
	}

	// Perform request with retries
	var resp *http.Response
	var lastErr error

	for attempt := 0; attempt <= c.config.MaxRetries; attempt++ {
		resp, lastErr = c.httpClient.Do(req)
		if lastErr == nil {
			break
		}

		if attempt < c.config.MaxRetries {
			waitTime := time.Duration(attempt+1) * time.Second
			time.Sleep(waitTime)
		}
	}

	if lastErr != nil {
		return &APIResponse{
			StatusCode:    0,
			Success:       false,
			Error:         fmt.Sprintf("request failed after %d attempts: %v", c.config.MaxRetries+1, lastErr),
			ExecutionTime: time.Since(startTime),
		}, nil
	}
	defer resp.Body.Close()

	// Read response body
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return &APIResponse{
			StatusCode:    resp.StatusCode,
			Success:       false,
			Error:         fmt.Sprintf("failed to read response body: %v", err),
			ExecutionTime: time.Since(startTime),
			Headers:       resp.Header,
		}, nil
	}

	// Parse JSON response
	var data map[string]interface{}
	if len(respBody) > 0 {
		if err := json.Unmarshal(respBody, &data); err != nil {
			// If JSON parsing fails, store as raw data
			data = map[string]interface{}{
				"raw_content": string(respBody),
			}
		}
	}

	// Determine success
	success := resp.StatusCode >= 200 && resp.StatusCode < 300
	var errorMsg string
	if !success {
		errorMsg = fmt.Sprintf("HTTP %d: %s", resp.StatusCode, resp.Status)
	}

	return &APIResponse{
		StatusCode:    resp.StatusCode,
		Data:          data,
		RawData:       respBody,
		Headers:       resp.Header,
		Success:       success,
		Error:         errorMsg,
		ExecutionTime: time.Since(startTime),
	}, nil
}

// GET performs a GET request
func (c *Client) GET(ctx context.Context, endpoint string, params map[string]string) (*APIResponse, error) {
	if len(params) > 0 {
		u, err := url.Parse(endpoint)
		if err != nil {
			return nil, fmt.Errorf("invalid endpoint: %w", err)
		}
		
		query := u.Query()
		for key, value := range params {
			query.Set(key, value)
		}
		u.RawQuery = query.Encode()
		endpoint = u.String()
	}
	
	return c.makeRequest(ctx, "GET", endpoint, nil, nil)
}

// POST performs a POST request
func (c *Client) POST(ctx context.Context, endpoint string, body interface{}) (*APIResponse, error) {
	return c.makeRequest(ctx, "POST", endpoint, body, nil)
}

// PUT performs a PUT request
func (c *Client) PUT(ctx context.Context, endpoint string, body interface{}) (*APIResponse, error) {
	return c.makeRequest(ctx, "PUT", endpoint, body, nil)
}

// PATCH performs a PATCH request
func (c *Client) PATCH(ctx context.Context, endpoint string, body interface{}) (*APIResponse, error) {
	return c.makeRequest(ctx, "PATCH", endpoint, body, nil)
}

// DELETE performs a DELETE request
func (c *Client) DELETE(ctx context.Context, endpoint string) (*APIResponse, error) {
	return c.makeRequest(ctx, "DELETE", endpoint, nil, nil)
}

// OPTIONS performs an OPTIONS request
func (c *Client) OPTIONS(ctx context.Context, endpoint string) (*APIResponse, error) {
	return c.makeRequest(ctx, "OPTIONS", endpoint, nil, nil)
}

// Convenience methods with default context
func (c *Client) Get(endpoint string, params map[string]string) (*APIResponse, error) {
	return c.GET(context.Background(), endpoint, params)
}

func (c *Client) Post(endpoint string, body interface{}) (*APIResponse, error) {
	return c.POST(context.Background(), endpoint, body)
}

func (c *Client) Put(endpoint string, body interface{}) (*APIResponse, error) {
	return c.PUT(context.Background(), endpoint, body)
}

func (c *Client) Patch(endpoint string, body interface{}) (*APIResponse, error) {
	return c.PATCH(context.Background(), endpoint, body)
}

func (c *Client) Delete(endpoint string) (*APIResponse, error) {
	return c.DELETE(context.Background(), endpoint)
}

func (c *Client) GetOptions(endpoint string) (*APIResponse, error) {
	return c.OPTIONS(context.Background(), endpoint)
}

// PacketFence-specific API methods

// TestConnection tests the API connection and authentication
func (c *Client) TestConnection() (*APIResponse, error) {
	return c.Get("/api/v1/status", nil)
}

// Node Management

// GetNodes retrieves a list of nodes
func (c *Client) GetNodes(limit int, cursor int, fields []string) (*APIResponse, error) {
	params := make(map[string]string)
	if limit > 0 {
		params["limit"] = strconv.Itoa(limit)
	}
	if cursor > 0 {
		params["cursor"] = strconv.Itoa(cursor)
	}
	if len(fields) > 0 {
		params["fields"] = strings.Join(fields, ",")
	}
	return c.Get("/api/v1/nodes", params)
}

// GetNode retrieves a specific node by ID
func (c *Client) GetNode(nodeID string) (*APIResponse, error) {
	return c.Get("/api/v1/node/"+nodeID, nil)
}

// CreateNode creates a new node
func (c *Client) CreateNode(nodeData map[string]interface{}) (*APIResponse, error) {
	return c.Post("/api/v1/nodes", nodeData)
}

// UpdateNode updates an existing node
func (c *Client) UpdateNode(nodeID string, nodeData map[string]interface{}) (*APIResponse, error) {
	return c.Put("/api/v1/node/"+nodeID, nodeData)
}

// DeleteNode deletes a node
func (c *Client) DeleteNode(nodeID string) (*APIResponse, error) {
	return c.Delete("/api/v1/node/" + nodeID)
}

// SearchNodes searches for nodes with criteria
func (c *Client) SearchNodes(searchCriteria map[string]interface{}) (*APIResponse, error) {
	return c.Post("/api/v1/nodes/search", searchCriteria)
}

// User Management

// GetUsers retrieves a list of users
func (c *Client) GetUsers(limit int, cursor int) (*APIResponse, error) {
	params := make(map[string]string)
	if limit > 0 {
		params["limit"] = strconv.Itoa(limit)
	}
	if cursor > 0 {
		params["cursor"] = strconv.Itoa(cursor)
	}
	return c.Get("/api/v1/users", params)
}

// GetUser retrieves a specific user by ID
func (c *Client) GetUser(userID string) (*APIResponse, error) {
	return c.Get("/api/v1/user/"+userID, nil)
}

// CreateUser creates a new user
func (c *Client) CreateUser(userData map[string]interface{}) (*APIResponse, error) {
	return c.Post("/api/v1/users", userData)
}

// UpdateUser updates an existing user
func (c *Client) UpdateUser(userID string, userData map[string]interface{}) (*APIResponse, error) {
	return c.Put("/api/v1/user/"+userID, userData)
}

// DeleteUser deletes a user
func (c *Client) DeleteUser(userID string) (*APIResponse, error) {
	return c.Delete("/api/v1/user/" + userID)
}

// SearchUsers searches for users with criteria
func (c *Client) SearchUsers(searchCriteria map[string]interface{}) (*APIResponse, error) {
	return c.Post("/api/v1/users/search", searchCriteria)
}

// Reports

// GetReports retrieves available reports
func (c *Client) GetReports() (*APIResponse, error) {
	return c.Get("/api/v1.1/reports", nil)
}

// GetReport retrieves a specific report
func (c *Client) GetReport(reportID string) (*APIResponse, error) {
	return c.Get("/api/v1.1/report/"+reportID, nil)
}

// SearchReport searches within a specific report
func (c *Client) SearchReport(reportID string, searchCriteria map[string]interface{}) (*APIResponse, error) {
	return c.Post("/api/v1.1/report/"+reportID+"/search", searchCriteria)
}

// Configuration

// GetConfig retrieves configuration
func (c *Client) GetConfig(section string) (*APIResponse, error) {
	endpoint := "/api/v1/config"
	if section != "" {
		endpoint += "/" + section
	}
	return c.Get(endpoint, nil)
}

// UpdateConfig updates configuration section
func (c *Client) UpdateConfig(section string, configData map[string]interface{}) (*APIResponse, error) {
	return c.Put("/api/v1/config/"+section, configData)
}

// Services

// GetServicesStatus retrieves the status of all services
func (c *Client) GetServicesStatus() (*APIResponse, error) {
	return c.Get("/api/v1/services/status", nil)
}

// RestartService restarts a specific service
func (c *Client) RestartService(serviceName string) (*APIResponse, error) {
	return c.Post("/api/v1/service/"+serviceName+"/restart", nil)
}

// StartService starts a specific service
func (c *Client) StartService(serviceName string) (*APIResponse, error) {
	return c.Post("/api/v1/service/"+serviceName+"/start", nil)
}

// StopService stops a specific service
func (c *Client) StopService(serviceName string) (*APIResponse, error) {
	return c.Post("/api/v1/service/"+serviceName+"/stop", nil)
}

// DHCP

// GetDHCPOptions retrieves DHCP options
func (c *Client) GetDHCPOptions() (*APIResponse, error) {
	return c.Get("/api/v1/dhcp_options", nil)
}

// Authentication Sources

// GetAuthSources retrieves authentication sources
func (c *Client) GetAuthSources() (*APIResponse, error) {
	return c.Get("/api/v1/config/sources", nil)
}

// Violations

// GetViolations retrieves violations
func (c *Client) GetViolations(limit int) (*APIResponse, error) {
	params := make(map[string]string)
	if limit > 0 {
		params["limit"] = strconv.Itoa(limit)
	}
	return c.Get("/api/v1/violations", params)
}

// GetViolation retrieves a specific violation
func (c *Client) GetViolation(violationID string) (*APIResponse, error) {
	return c.Get("/api/v1/violation/"+violationID, nil)
}

// Network Devices

// GetSwitches retrieves network switches configuration
func (c *Client) GetSwitches() (*APIResponse, error) {
	return c.Get("/api/v1/config/switches", nil)
}

// GetSwitch retrieves specific switch configuration
func (c *Client) GetSwitch(switchID string) (*APIResponse, error) {
	return c.Get("/api/v1/config/switch/"+switchID, nil)
}

// EndpointInfo represents information about an API endpoint
type EndpointInfo struct {
	Category    string
	Endpoints   []string
}

// GetAllEndpointsInfo returns information about all available endpoints
func (c *Client) GetAllEndpointsInfo() map[string][]string {
	return map[string][]string{
		"Node Management": {
			"GET /api/v1/nodes - List all nodes",
			"GET /api/v1/node/{id} - Get specific node", 
			"POST /api/v1/nodes - Create node",
			"PUT /api/v1/node/{id} - Update node",
			"DELETE /api/v1/node/{id} - Delete node",
			"POST /api/v1/nodes/search - Search nodes",
		},
		"User Management": {
			"GET /api/v1/users - List all users",
			"GET /api/v1/user/{id} - Get specific user",
			"POST /api/v1/users - Create user", 
			"PUT /api/v1/user/{id} - Update user",
			"DELETE /api/v1/user/{id} - Delete user",
		},
		"Reports": {
			"GET /api/v1.1/reports - List reports",
			"GET /api/v1.1/report/{id} - Get specific report",
			"POST /api/v1.1/report/{id}/search - Search report",
		},
		"Configuration": {
			"GET /api/v1/config - Get configuration",
			"GET /api/v1/config/{section} - Get config section", 
			"PUT /api/v1/config/{section} - Update config section",
		},
		"Services": {
			"GET /api/v1/services/status - Service status",
			"POST /api/v1/service/{name}/start - Start service",
			"POST /api/v1/service/{name}/stop - Stop service",
			"POST /api/v1/service/{name}/restart - Restart service",
		},
		"System": {
			"GET /api/v1/status - System status",
			"GET /api/v1/dhcp_options - DHCP options",
			"GET /api/v1/config/sources - Auth sources", 
			"GET /api/v1/config/switches - Network switches",
		},
	}
}