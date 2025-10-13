package main


import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"

	pfclient "github.com/inverse-inc/packetfence-api-client-go"
)

var (
	cfgFile     string
	client      *pfclient.Client
	interactive bool
	
	// Colors for output
	green  = color.New(color.FgGreen).SprintFunc()
	red    = color.New(color.FgRed).SprintFunc()
	yellow = color.New(color.FgYellow).SprintFunc()
	cyan   = color.New(color.FgCyan).SprintFunc()
	blue   = color.New(color.FgBlue).SprintFunc()
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "pf-api-client",
	Short: "PacketFence API Client and Testing Tool",
	Long: `A comprehensive Go client for the PacketFence API that provides:
- Complete API endpoint coverage
- Interactive testing capabilities  
- Automated test suites
- Performance monitoring
- Multiple authentication methods

Example usage:
  pf-api-client connect --url https://pf.example.com:9999
  pf-api-client test basic
  pf-api-client get nodes --limit 10
  pf-api-client interactive`,
}

// connectCmd handles API connection
var connectCmd = &cobra.Command{
	Use:   "connect",
	Short: "Connect to PacketFence API",
	Long:  "Establish connection to PacketFence API server and test authentication",
	Run: func(cmd *cobra.Command, args []string) {
		config := buildClientConfig()
		
		var err error
		client, err = pfclient.NewClient(config)
		if err != nil {
			fmt.Printf("%s Failed to create client: %v\n", red("✗"), err)
			os.Exit(1)
		}

		fmt.Printf("%s Connecting to PacketFence API at %s\n", blue("🔗"), config.BaseURL)
		
		response, err := client.TestConnection()
		if err != nil {
			fmt.Printf("%s Connection error: %v\n", red("✗"), err)
			os.Exit(1)
		}

		if response.Success {
			fmt.Printf("%s Successfully connected to PacketFence API\n", green("✓"))
			fmt.Printf("  Server response time: %v\n", response.ExecutionTime)
		} else {
			fmt.Printf("%s Failed to connect: %s\n", red("✗"), response.Error)
			os.Exit(1)
		}
	},
}

// testCmd handles various testing scenarios
var testCmd = &cobra.Command{
	Use:   "test [basic|comprehensive|endpoint]",
	Short: "Run API tests",
	Long:  "Run various test suites against the PacketFence API",
}

var testBasicCmd = &cobra.Command{
	Use:   "basic",
	Short: "Run basic connectivity tests",
	Run: func(cmd *cobra.Command, args []string) {
		ensureConnected()
		runBasicTests()
	},
}

var testComprehensiveCmd = &cobra.Command{
	Use:   "comprehensive",
	Short: "Run comprehensive test suite",
	Run: func(cmd *cobra.Command, args []string) {
		ensureConnected()
		runComprehensiveTests()
	},
}

// getCmd handles GET requests to specific endpoints
var getCmd = &cobra.Command{
	Use:   "get [endpoint]",
	Short: "Make GET request to API endpoint",
	Long:  "Make a GET request to a specific API endpoint with optional parameters",
}

var getNodesCmd = &cobra.Command{
	Use:   "nodes",
	Short: "Get nodes from API",
	Run: func(cmd *cobra.Command, args []string) {
		ensureConnected()
		
		limit, _ := cmd.Flags().GetInt("limit")
		cursor, _ := cmd.Flags().GetInt("cursor")
		fields, _ := cmd.Flags().GetStringSlice("fields")
		
		response, err := client.GetNodes(limit, cursor, fields)
		if err != nil {
			fmt.Printf("%s Error: %v\n", red("✗"), err)
			return
		}
		
		printResponse("GET /api/v1/nodes", response)
	},
}

var getUsersCmd = &cobra.Command{
	Use:   "users",
	Short: "Get users from API",
	Run: func(cmd *cobra.Command, args []string) {
		ensureConnected()
		
		limit, _ := cmd.Flags().GetInt("limit")
		cursor, _ := cmd.Flags().GetInt("cursor")
		
		response, err := client.GetUsers(limit, cursor)
		if err != nil {
			fmt.Printf("%s Error: %v\n", red("✗"), err)
			return
		}
		
		printResponse("GET /api/v1/users", response)
	},
}

var getStatusCmd = &cobra.Command{
	Use:   "status",
	Short: "Get system status",
	Run: func(cmd *cobra.Command, args []string) {
		ensureConnected()
		
		response, err := client.TestConnection()
		if err != nil {
			fmt.Printf("%s Error: %v\n", red("✗"), err)
			return
		}
		
		printResponse("GET /api/v1/status", response)
	},
}

var getReportsCmd = &cobra.Command{
	Use:   "reports",
	Short: "Get available reports",
	Run: func(cmd *cobra.Command, args []string) {
		ensureConnected()
		
		response, err := client.GetReports()
		if err != nil {
			fmt.Printf("%s Error: %v\n", red("✗"), err)
			return
		}
		
		printResponse("GET /api/v1.1/reports", response)
	},
}

// postCmd handles POST requests  
var postCmd = &cobra.Command{
	Use:   "post [endpoint] [json-data]",
	Short: "Make POST request to API endpoint",
	Args:  cobra.ExactArgs(2),
	Run: func(cmd *cobra.Command, args []string) {
		ensureConnected()
		
		endpoint := args[0]
		jsonData := args[1]
		
		var data map[string]interface{}
		if err := json.Unmarshal([]byte(jsonData), &data); err != nil {
			fmt.Printf("%s Invalid JSON data: %v\n", red("✗"), err)
			return
		}
		
		response, err := client.Post(endpoint, data)
		if err != nil {
			fmt.Printf("%s Error: %v\n", red("✗"), err)
			return
		}
		
		printResponse(fmt.Sprintf("POST %s", endpoint), response)
	},
}

// interactiveCmd starts interactive mode
var interactiveCmd = &cobra.Command{
	Use:   "interactive",
	Short: "Start interactive mode",
	Run: func(cmd *cobra.Command, args []string) {
		startInteractiveMode()
	},
}

// endpointsCmd lists all available endpoints
var endpointsCmd = &cobra.Command{
	Use:   "endpoints",
	Short: "List all available API endpoints",
	Run: func(cmd *cobra.Command, args []string) {
		printEndpoints()
	},
}

// Helper functions

func buildClientConfig() *pfclient.Config {
	config := pfclient.DefaultConfig()
	
	if url := viper.GetString("url"); url != "" {
		config.BaseURL = url
	}
	if username := viper.GetString("username"); username != "" {
		config.Username = username
	}
	if password := viper.GetString("password"); password != "" {
		config.Password = password
	}
	if token := viper.GetString("token"); token != "" {
		config.Token = token
	}
	if apiKey := viper.GetString("api-key"); apiKey != "" {
		config.APIKey = apiKey
	}
	
	config.VerifySSL = viper.GetBool("verify-ssl")
	config.Timeout = time.Duration(viper.GetInt("timeout")) * time.Second
	config.MaxRetries = viper.GetInt("max-retries")
	
	return config
}

func ensureConnected() {
	if client == nil {
		config := buildClientConfig()
		var err error
		client, err = pfclient.NewClient(config)
		if err != nil {
			fmt.Printf("%s Failed to create client: %v\n", red("✗"), err)
			os.Exit(1)
		}
	}
}

func printResponse(endpoint string, response *pfclient.APIResponse) {
	timestamp := time.Now().Format("15:04:05")
	
	var statusIcon, statusColor string
	if response.Success {
		statusIcon = "✓"
		statusColor = green(statusIcon)
	} else {
		statusIcon = "✗"  
		statusColor = red(statusIcon)
	}
	
	fmt.Printf("\n%s [%s] %s\n", statusColor, timestamp, endpoint)
	fmt.Printf("   Status: %s%d%s\n", 
		func() string { if response.Success { return green("") } else { return red("") } }(),
		response.StatusCode,
		func() string { if response.Success { return green("") } else { return red("") } }())
	fmt.Printf("   Time: %v\n", response.ExecutionTime)
	
	if response.Error != "" {
		fmt.Printf("   Error: %s\n", red(response.Error))
	}
	
	if response.Data != nil {
		jsonBytes, err := json.MarshalIndent(response.Data, "   ", "  ")
		if err == nil {
			jsonStr := string(jsonBytes)
			// Limit output size for readability
			if len(jsonStr) > 2000 {
				lines := strings.Split(jsonStr, "\n")
				if len(lines) > 20 {
					truncated := strings.Join(lines[:20], "\n") + fmt.Sprintf("\n   ... (%d more lines) ...", len(lines)-20)
					jsonStr = truncated
				}
			}
			fmt.Printf("   Response:\n   %s\n", cyan(jsonStr))
		}
	}
}

func runBasicTests() {
	fmt.Printf("\n%s Running Basic API Tests\n", blue("🧪"))
	fmt.Println(strings.Repeat("=", 60))
	
	tests := []struct {
		name string
		fn   func() (*pfclient.APIResponse, error)
	}{
		{"System Status", client.TestConnection},
		{"Get Reports", client.GetReports},
		{"Get Services Status", client.GetServicesStatus},
		{"Get Configuration", func() (*pfclient.APIResponse, error) { return client.GetConfig("") }},
	}
	
	passed := 0
	total := len(tests)
	
	for _, test := range tests {
		fmt.Printf("\n%s Running: %s\n", blue("►"), test.name)
		response, err := test.fn()
		
		if err != nil {
			fmt.Printf("  %s Test failed with error: %v\n", red("✗"), err)
			continue
		}
		
		printResponse(test.name, response)
		if response.Success {
			passed++
		}
	}
	
	fmt.Printf("\n%s Test Results: %s/%d passed\n", blue("📊"), 
		func() string {
			if passed == total {
				return green(strconv.Itoa(passed))
			}
			return yellow(strconv.Itoa(passed))
		}(), total)
}

func runComprehensiveTests() {
	fmt.Printf("\n%s Running Comprehensive API Test Suite\n", blue("🧪"))
	fmt.Println(strings.Repeat("=", 60))
	
	tests := []struct {
		name string
		fn   func() (*pfclient.APIResponse, error)
	}{
		// System endpoints
		{"System Status", client.TestConnection},
		{"Get Services Status", client.GetServicesStatus},
		
		// Configuration endpoints  
		{"Get Configuration", func() (*pfclient.APIResponse, error) { return client.GetConfig("") }},
		{"Get Authentication Sources", client.GetAuthSources},
		{"Get DHCP Options", client.GetDHCPOptions},
		{"Get Switches", client.GetSwitches},
		
		// Reporting endpoints
		{"Get Reports", client.GetReports},
		
		// Data endpoints (read-only)
		{"Get Nodes", func() (*pfclient.APIResponse, error) { return client.GetNodes(5, 0, nil) }},
		{"Get Users", func() (*pfclient.APIResponse, error) { return client.GetUsers(5, 0) }},
		{"Get Violations", func() (*pfclient.APIResponse, error) { return client.GetViolations(5) }},
	}
	
	passed := 0
	total := len(tests)
	
	for i, test := range tests {
		fmt.Printf("\n[%d/%d] %s Running: %s\n", i+1, total, blue("►"), test.name)
		response, err := test.fn()
		
		if err != nil {
			fmt.Printf("  %s Test failed with error: %v\n", red("✗"), err)
			continue
		}
		
		printResponse(test.name, response)
		if response.Success {
			passed++
		}
		
		// Small delay to avoid overwhelming the server
		time.Sleep(100 * time.Millisecond)
	}
	
	fmt.Printf("\n%s Test Results: %s/%d passed\n", blue("📊"), 
		func() string {
			if passed == total {
				return green(strconv.Itoa(passed))
			}
			return yellow(strconv.Itoa(passed))
		}(), total)
}

func printEndpoints() {
	if client == nil {
		// Create a temporary client just to get endpoint info
		config := pfclient.DefaultConfig()
		client, _ = pfclient.NewClient(config)
	}
	
	endpoints := client.GetAllEndpointsInfo()
	
	fmt.Printf("\n%s Available PacketFence API Endpoints:\n", blue("📋"))
	fmt.Println(strings.Repeat("=", 60))
	
	for category, endpointList := range endpoints {
		fmt.Printf("\n%s %s:\n", blue("🔹"), category)
		for _, endpoint := range endpointList {
			fmt.Printf("   %s\n", endpoint)
		}
	}
	fmt.Println()
}

func startInteractiveMode() {
	fmt.Printf("\n%s PacketFence API Interactive Testing Mode\n", blue("🔧"))
	fmt.Printf("%s Type 'help' for available commands, 'quit' to exit\n", yellow(""))
	
	// Implementation of interactive mode would go here
	// For now, show the available commands
	fmt.Printf("\n%s Interactive mode not yet implemented in this version\n", yellow("⚠️"))
	fmt.Printf("Use the individual commands instead:\n")
	fmt.Printf("  pf-api-client connect --url https://pf.example.com:9999\n")
	fmt.Printf("  pf-api-client test basic\n")
	fmt.Printf("  pf-api-client get nodes --limit 5\n")
	fmt.Printf("  pf-api-client endpoints\n")
}

func init() {
	cobra.OnInitialize(initConfig)
	
	// Global flags
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.pf-api-client.yaml)")
	rootCmd.PersistentFlags().String("url", "https://localhost:9999", "PacketFence API base URL")
	rootCmd.PersistentFlags().String("username", "admin", "Username for authentication") 
	rootCmd.PersistentFlags().String("password", "admin", "Password for authentication")
	rootCmd.PersistentFlags().String("token", "", "Bearer token for authentication")
	rootCmd.PersistentFlags().String("api-key", "", "API key for authentication")
	rootCmd.PersistentFlags().Bool("verify-ssl", false, "Verify SSL certificates")
	rootCmd.PersistentFlags().Int("timeout", 30, "Request timeout in seconds")
	rootCmd.PersistentFlags().Int("max-retries", 3, "Maximum retry attempts")
	rootCmd.PersistentFlags().BoolVarP(&interactive, "interactive", "i", false, "Start in interactive mode")
	
	// Bind flags to viper
	viper.BindPFlag("url", rootCmd.PersistentFlags().Lookup("url"))
	viper.BindPFlag("username", rootCmd.PersistentFlags().Lookup("username"))
	viper.BindPFlag("password", rootCmd.PersistentFlags().Lookup("password"))
	viper.BindPFlag("token", rootCmd.PersistentFlags().Lookup("token"))
	viper.BindPFlag("api-key", rootCmd.PersistentFlags().Lookup("api-key"))
	viper.BindPFlag("verify-ssl", rootCmd.PersistentFlags().Lookup("verify-ssl"))
	viper.BindPFlag("timeout", rootCmd.PersistentFlags().Lookup("timeout"))
	viper.BindPFlag("max-retries", rootCmd.PersistentFlags().Lookup("max-retries"))
	
	// Add subcommands
	rootCmd.AddCommand(connectCmd)
	rootCmd.AddCommand(testCmd)
	rootCmd.AddCommand(getCmd)
	rootCmd.AddCommand(postCmd)
	rootCmd.AddCommand(interactiveCmd)
	rootCmd.AddCommand(endpointsCmd)
	
	// Add test subcommands
	testCmd.AddCommand(testBasicCmd)
	testCmd.AddCommand(testComprehensiveCmd)
	
	// Add get subcommands
	getCmd.AddCommand(getNodesCmd)
	getCmd.AddCommand(getUsersCmd) 
	getCmd.AddCommand(getStatusCmd)
	getCmd.AddCommand(getReportsCmd)
	
	// Flags for get nodes
	getNodesCmd.Flags().Int("limit", 25, "Maximum number of nodes to retrieve")
	getNodesCmd.Flags().Int("cursor", 0, "Cursor for pagination")
	getNodesCmd.Flags().StringSlice("fields", []string{}, "Additional fields to include")
	
	// Flags for get users
	getUsersCmd.Flags().Int("limit", 25, "Maximum number of users to retrieve")
	getUsersCmd.Flags().Int("cursor", 0, "Cursor for pagination")
}

func initConfig() {
	if cfgFile != "" {
		viper.SetConfigFile(cfgFile)
	} else {
		home, err := os.UserHomeDir()
		cobra.CheckErr(err)

		viper.AddConfigPath(home)
		viper.AddConfigPath(".")
		viper.SetConfigType("yaml")
		viper.SetConfigName(".pf-api-client")
	}

	viper.AutomaticEnv()
	viper.SetEnvPrefix("PFAPI")

	if err := viper.ReadInConfig(); err == nil {
		fmt.Printf("Using config file: %s\n", viper.ConfigFileUsed())
	}
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		log.Fatal(err)
	}
}