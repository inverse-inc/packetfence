package main

import (
	"fmt"
	"log"
	"strings"
	"time"

	pfclient "github.com/inverse-inc/packetfence-api-client-go"
)

func main() {
	fmt.Println("🚀 PacketFence API Client (Go) - Usage Examples")
	fmt.Println(strings.Repeat("=", 60))

	// Example 1: Basic Connection
	fmt.Println("\n🔗 Example 1: Basic Connection and Status Check")
	fmt.Println(strings.Repeat("-", 50))

	// Create client configuration
	config := &pfclient.Config{
		BaseURL:   "https://localhost:9999",
		Username:  "admin", 
		Password:  "admin",
		VerifySSL: false, // For development/testing
		Timeout:   30 * time.Second,
	}

	// Create client
	client, err := pfclient.NewClient(config)
	if err != nil {
		log.Fatalf("❌ Failed to create client: %v", err)
	}

	// Test connection
	fmt.Printf("Testing API connection to %s...\n", config.BaseURL)
	response, err := client.TestConnection()
	if err != nil {
		fmt.Printf("❌ Connection error: %v\n", err)
		return
	}

	if response.Success {
		fmt.Printf("✅ Connected successfully! (Response time: %v)\n", response.ExecutionTime)
		printResponseData("System Status", response)
	} else {
		fmt.Printf("❌ Connection failed: %s\n", response.Error)
		return
	}

	// Example 2: Node Management
	fmt.Println("\n📱 Example 2: Node Management")
	fmt.Println(strings.Repeat("-", 30))

	// Get nodes
	fmt.Println("Fetching nodes...")
	nodesResponse, err := client.GetNodes(5, 0, []string{"mac", "pid", "status"})
	if err != nil {
		fmt.Printf("❌ Error fetching nodes: %v\n", err)
	} else if nodesResponse.Success {
		printResponseData("Nodes List", nodesResponse)
		
		// Extract and display node information
		if items, ok := nodesResponse.Data["items"].([]interface{}); ok {
			fmt.Printf("✅ Found %d nodes (showing first few):\n", len(items))
			for i, item := range items {
				if i >= 3 { // Show only first 3
					break
				}
				if node, ok := item.(map[string]interface{}); ok {
					mac := getString(node, "mac")
					pid := getString(node, "pid") 
					status := getString(node, "status")
					fmt.Printf("  %d. MAC: %s, User: %s, Status: %s\n", i+1, mac, pid, status)
				}
			}
		}
	} else {
		fmt.Printf("❌ Failed to get nodes: %s\n", nodesResponse.Error)
	}

	// Example 3: Search Nodes
	fmt.Println("\nSearching for nodes...")
	searchResponse, err := client.SearchNodes(map[string]interface{}{
		"query": map[string]interface{}{
			"limit": 3,
		},
	})
	if err != nil {
		fmt.Printf("❌ Search error: %v\n", err)
	} else if searchResponse.Success {
		fmt.Printf("✅ Search completed (Response time: %v)\n", searchResponse.ExecutionTime)
	} else {
		fmt.Printf("❌ Search failed: %s\n", searchResponse.Error)
	}

	// Example 4: User Management  
	fmt.Println("\n👥 Example 3: User Management")
	fmt.Println(strings.Repeat("-", 26))

	fmt.Println("Fetching users...")
	usersResponse, err := client.GetUsers(5, 0)
	if err != nil {
		fmt.Printf("❌ Error fetching users: %v\n", err)
	} else if usersResponse.Success {
		printResponseData("Users List", usersResponse)
		
		if items, ok := usersResponse.Data["items"].([]interface{}); ok {
			fmt.Printf("✅ Found %d users (showing first few):\n", len(items))
			for i, item := range items {
				if i >= 3 { // Show only first 3
					break
				}
				if user, ok := item.(map[string]interface{}); ok {
					pid := getString(user, "pid")
					email := getString(user, "email") 
					status := getString(user, "status")
					fmt.Printf("  %d. PID: %s, Email: %s, Status: %s\n", i+1, pid, email, status)
				}
			}
		}
	} else {
		fmt.Printf("❌ Failed to get users: %s\n", usersResponse.Error)
	}

	// Example 5: System Information
	fmt.Println("\n⚙️ Example 4: System Information")
	fmt.Println(strings.Repeat("-", 30))

	// Get services status
	fmt.Println("Checking services status...")
	servicesResponse, err := client.GetServicesStatus()
	if err != nil {
		fmt.Printf("❌ Error getting services: %v\n", err)
	} else if servicesResponse.Success {
		fmt.Printf("✅ Services status retrieved (Response time: %v)\n", servicesResponse.ExecutionTime)
		if servicesResponse.Data != nil {
			fmt.Printf("  Found %d service entries\n", len(servicesResponse.Data))
		}
	} else {
		fmt.Printf("❌ Failed to get services: %s\n", servicesResponse.Error)
	}

	// Get configuration
	fmt.Println("\nRetrieving configuration...")
	configResponse, err := client.GetConfig("")
	if err != nil {
		fmt.Printf("❌ Error getting configuration: %v\n", err)
	} else if configResponse.Success {
		fmt.Printf("✅ Configuration retrieved (Response time: %v)\n", configResponse.ExecutionTime)
		if configResponse.Data != nil {
			var sections []string
			for key := range configResponse.Data {
				sections = append(sections, key)
				if len(sections) >= 5 { // Show first 5 sections
					break
				}
			}
			fmt.Printf("  Configuration sections: %v...\n", sections)
		}
	} else {
		fmt.Printf("❌ Failed to get configuration: %s\n", configResponse.Error)
	}

	// Example 6: Reports
	fmt.Println("\n📊 Example 5: Reports")
	fmt.Println(strings.Repeat("-", 17))

	fmt.Println("Fetching available reports...")
	reportsResponse, err := client.GetReports()
	if err != nil {
		fmt.Printf("❌ Error fetching reports: %v\n", err)
	} else if reportsResponse.Success {
		printResponseData("Reports", reportsResponse)
		
		if items, ok := reportsResponse.Data["items"].([]interface{}); ok {
			fmt.Printf("✅ Found %d available reports\n", len(items))
		} else if reportsResponse.Data != nil {
			fmt.Printf("✅ Reports data retrieved\n")
		}
	} else {
		fmt.Printf("❌ Failed to get reports: %s\n", reportsResponse.Error)
	}

	// Example 7: Performance Monitoring
	fmt.Println("\n⏱️ Example 6: Performance Monitoring")
	fmt.Println(strings.Repeat("-", 33))

	endpoints := []string{
		"/api/v1/status",
		"/api/v1/nodes?limit=1",
		"/api/v1/users?limit=1", 
		"/api/v1/violations?limit=1",
	}

	fmt.Println("Testing endpoint performance...")
	var totalTime time.Duration
	successCount := 0

	for _, endpoint := range endpoints {
		fmt.Printf("Testing %s...\n", endpoint)
		response, err := client.Get(endpoint, nil)
		
		if err != nil {
			fmt.Printf("  ❌ %s - Error: %v\n", endpoint, err)
		} else {
			statusIcon := "✅"
			if !response.Success {
				statusIcon = "❌"
			} else {
				successCount++
			}
			
			fmt.Printf("  %s %d - %v\n", statusIcon, response.StatusCode, response.ExecutionTime)
			totalTime += response.ExecutionTime
		}
	}

	// Performance summary
	if successCount > 0 {
		avgTime := totalTime / time.Duration(successCount)
		fmt.Printf("\n📈 Performance Summary:\n")
		fmt.Printf("  Successful requests: %d/%d\n", successCount, len(endpoints))
		fmt.Printf("  Average response time: %v\n", avgTime)
		fmt.Printf("  Total time: %v\n", totalTime)
	}

	// Example 8: Error Handling
	fmt.Println("\n🚨 Example 7: Error Handling")
	fmt.Println(strings.Repeat("-", 25))

	// Test with non-existent endpoint
	fmt.Println("Testing non-existent endpoint...")
	badResponse, err := client.Get("/api/v1/nonexistent", nil)
	if err != nil {
		fmt.Printf("❌ Request error: %v\n", err)
	} else if !badResponse.Success {
		fmt.Printf("❌ Expected error: %d - %s\n", badResponse.StatusCode, badResponse.Error)
	} else {
		fmt.Printf("⚠️ Unexpected success (endpoint might exist)\n")
	}

	// Test with invalid node ID
	fmt.Println("\nTesting invalid node lookup...")
	invalidResponse, err := client.GetNode("invalid-mac-address") 
	if err != nil {
		fmt.Printf("❌ Request error: %v\n", err)
	} else if !invalidResponse.Success {
		fmt.Printf("❌ Expected error: %d - %s\n", invalidResponse.StatusCode, invalidResponse.Error)
	} else {
		fmt.Printf("⚠️ Unexpected success\n")
	}

	fmt.Println("\n💡 Always check response.Success before using response.Data")

	// Final summary
	fmt.Println("\n" + strings.Repeat("=", 60))
	fmt.Println("🎉 All examples completed!")
	fmt.Println("\n📚 Next Steps:")
	fmt.Println("  1. Modify the connection parameters above for your environment")
	fmt.Println("  2. Explore the CLI tool: ./bin/pf-api-client --help")
	fmt.Println("  3. Run comprehensive tests: ./bin/pf-test-suite test-suite")
	fmt.Println("  4. Read the documentation in README.md")
}

// Helper functions
func printResponseData(title string, response *pfclient.APIResponse) {
	fmt.Printf("  %s response: %d (%v)\n", title, response.StatusCode, response.ExecutionTime)
}

func getString(data map[string]interface{}, key string) string {
	if val, ok := data[key]; ok {
		if str, ok := val.(string); ok {
			return str
		}
	}
	return "N/A"
}