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
	// Colors for output
	green  = color.New(color.FgGreen).SprintFunc()
	red    = color.New(color.FgRed).SprintFunc()
	yellow = color.New(color.FgYellow).SprintFunc()
	cyan   = color.New(color.FgCyan).SprintFunc()
	blue   = color.New(color.FgBlue).SprintFunc()
)

// TestCase represents a single test case
type TestCase struct {
	Name        string
	Description string
	Endpoint    string
	Method      string
	TestFunc    func(*pfclient.Client) (*pfclient.APIResponse, error)
}

// TestResult represents the result of a test case
type TestResult struct {
	Name          string        `json:"name"`
	Success       bool          `json:"success"`
	StatusCode    int           `json:"status_code"`
	ExecutionTime time.Duration `json:"execution_time"`
	Error         string        `json:"error,omitempty"`
	Description   string        `json:"description"`
	Timestamp     time.Time     `json:"timestamp"`
}

// TestSuite represents a collection of test cases
type TestSuite struct {
	client  *pfclient.Client
	results []TestResult
}

// NewTestSuite creates a new test suite
func NewTestSuite(client *pfclient.Client) *TestSuite {
	return &TestSuite{
		client:  client,
		results: make([]TestResult, 0),
	}
}

// RunTest executes a single test case
func (ts *TestSuite) RunTest(testCase TestCase) TestResult {
	fmt.Printf("  Running: %s\n", testCase.Name)
	
	startTime := time.Now()
	response, err := testCase.TestFunc(ts.client)
	executionTime := time.Since(startTime)
	
	var success bool
	var statusCode int
	var errorMsg string
	
	if err != nil {
		success = false
		statusCode = 0
		errorMsg = err.Error()
	} else {
		success = response.Success
		statusCode = response.StatusCode
		if response.Error != "" {
			errorMsg = response.Error
		}
	}
	
	// Print result
	statusIcon := "✓"
	if !success {
		statusIcon = "✗"
	}
	
	statusColor := green
	if !success {
		statusColor = red
	}
	
	fmt.Printf("    %s %s (%d, %v)\n", 
		statusColor(statusIcon), testCase.Name, statusCode, executionTime)
	
	if !success {
		fmt.Printf("      Error: %s\n", red(errorMsg))
	}
	
	result := TestResult{
		Name:          testCase.Name,
		Success:       success,
		StatusCode:    statusCode,
		ExecutionTime: executionTime,
		Error:         errorMsg,
		Description:   testCase.Description,
		Timestamp:     time.Now(),
	}
	
	ts.results = append(ts.results, result)
	return result
}

// RunAllTests executes all test cases in the suite
func (ts *TestSuite) RunAllTests(testCases []TestCase) {
	fmt.Printf("\n%s Running PacketFence API Test Suite\n", blue("🧪"))
	fmt.Println(strings.Repeat("=", 60))
	
	passed := 0
	failed := 0
	totalTime := time.Duration(0)
	
	for i, testCase := range testCases {
		fmt.Printf("\n[%d/%d] %s\n", i+1, len(testCases), testCase.Description)
		result := ts.RunTest(testCase)
		
		if result.Success {
			passed++
		} else {
			failed++
		}
		
		totalTime += result.ExecutionTime
		
		// Small delay to avoid overwhelming the server
		time.Sleep(100 * time.Millisecond)
	}
	
	// Print summary
	ts.printSummary(passed, failed, len(testCases), totalTime)
}

func (ts *TestSuite) printSummary(passed, failed, total int, totalTime time.Duration) {
	fmt.Printf("\n%s\n", strings.Repeat("=", 60))
	fmt.Printf("%s Test Execution Summary\n", blue("📊"))
	fmt.Printf("%s\n", strings.Repeat("=", 60))
	
	fmt.Printf("Total Tests:     %d\n", total)
	fmt.Printf("Passed:          %s\n", green(strconv.Itoa(passed)))
	fmt.Printf("Failed:          %s\n", red(strconv.Itoa(failed)))
	
	successRate := float64(passed) / float64(total) * 100
	fmt.Printf("Success Rate:    %.1f%%\n", successRate)
	fmt.Printf("Total Time:      %v\n", totalTime)
	fmt.Printf("Average Time:    %v\n", totalTime/time.Duration(total))
	
	// Failed tests details
	if failed > 0 {
		fmt.Printf("\n%s Failed Tests:\n", red("❌"))
		for _, result := range ts.results {
			if !result.Success {
				fmt.Printf("  • %s: %s\n", result.Name, result.Error)
			}
		}
	}
	
	// Performance insights
	var slowTests []TestResult
	for _, result := range ts.results {
		if result.ExecutionTime > 2*time.Second {
			slowTests = append(slowTests, result)
		}
	}
	
	if len(slowTests) > 0 {
		fmt.Printf("\n%s Slow Tests (>2s):\n", yellow("⚠️"))
		for _, result := range slowTests {
			fmt.Printf("  • %s: %v\n", result.Name, result.ExecutionTime)
		}
	}
}

// SaveResults saves test results to a file
func (ts *TestSuite) SaveResults(filename string) error {
	summary := map[string]interface{}{
		"total_tests":           len(ts.results),
		"passed":               len(ts.getPassedTests()),
		"failed":               len(ts.getFailedTests()),
		"success_rate":         ts.getSuccessRate(),
		"timestamp":            time.Now(),
		"test_results":         ts.results,
	}
	
	data, err := json.MarshalIndent(summary, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal results: %w", err)
	}
	
	if err := os.WriteFile(filename, data, 0644); err != nil {
		return fmt.Errorf("failed to write results file: %w", err)
	}
	
	fmt.Printf("\n%s Test results saved to: %s\n", green("💾"), filename)
	return nil
}

func (ts *TestSuite) getPassedTests() []TestResult {
	var passed []TestResult
	for _, result := range ts.results {
		if result.Success {
			passed = append(passed, result)
		}
	}
	return passed
}

func (ts *TestSuite) getFailedTests() []TestResult {
	var failed []TestResult
	for _, result := range ts.results {
		if !result.Success {
			failed = append(failed, result)
		}
	}
	return failed
}

func (ts *TestSuite) getSuccessRate() float64 {
	if len(ts.results) == 0 {
		return 0
	}
	return float64(len(ts.getPassedTests())) / float64(len(ts.results)) * 100
}

// generateTestCases creates the standard test cases for PacketFence API
func generateTestCases() []TestCase {
	return []TestCase{
		{
			Name:        "System Status",
			Description: "Check system status and health",
			Endpoint:    "/api/v1/status",
			Method:      "GET",
			TestFunc:    func(c *pfclient.Client) (*pfclient.APIResponse, error) {
				return c.TestConnection()
			},
		},
		{
			Name:        "Services Status",
			Description: "Check status of PacketFence services",
			Endpoint:    "/api/v1/services/status",
			Method:      "GET",
			TestFunc:    func(c *pfclient.Client) (*pfclient.APIResponse, error) {
				return c.GetServicesStatus()
			},
		},
		{
			Name:        "Get Configuration",
			Description: "Retrieve system configuration",
			Endpoint:    "/api/v1/config",
			Method:      "GET",
			TestFunc:    func(c *pfclient.Client) (*pfclient.APIResponse, error) {
				return c.GetConfig("")
			},
		},
		{
			Name:        "Get Authentication Sources",
			Description: "Get configured authentication sources",
			Endpoint:    "/api/v1/config/sources",
			Method:      "GET",
			TestFunc:    func(c *pfclient.Client) (*pfclient.APIResponse, error) {
				return c.GetAuthSources()
			},
		},
		{
			Name:        "Get Network Switches",
			Description: "Get network switches configuration",
			Endpoint:    "/api/v1/config/switches",
			Method:      "GET",
			TestFunc:    func(c *pfclient.Client) (*pfclient.APIResponse, error) {
				return c.GetSwitches()
			},
		},
		{
			Name:        "Get DHCP Options",
			Description: "Get DHCP options configuration",
			Endpoint:    "/api/v1/dhcp_options",
			Method:      "GET",
			TestFunc:    func(c *pfclient.Client) (*pfclient.APIResponse, error) {
				return c.GetDHCPOptions()
			},
		},
		{
			Name:        "List Reports",
			Description: "List available dynamic reports",
			Endpoint:    "/api/v1.1/reports",
			Method:      "GET",
			TestFunc:    func(c *pfclient.Client) (*pfclient.APIResponse, error) {
				return c.GetReports()
			},
		},
		{
			Name:        "List Nodes",
			Description: "List network nodes/devices",
			Endpoint:    "/api/v1/nodes",
			Method:      "GET",
			TestFunc:    func(c *pfclient.Client) (*pfclient.APIResponse, error) {
				return c.GetNodes(5, 0, nil)
			},
		},
		{
			Name:        "List Users",
			Description: "List registered users",
			Endpoint:    "/api/v1/users", 
			Method:      "GET",
			TestFunc:    func(c *pfclient.Client) (*pfclient.APIResponse, error) {
				return c.GetUsers(5, 0)
			},
		},
		{
			Name:        "List Violations",
			Description: "List security violations",
			Endpoint:    "/api/v1/violations",
			Method:      "GET", 
			TestFunc:    func(c *pfclient.Client) (*pfclient.APIResponse, error) {
				return c.GetViolations(5)
			},
		},
		{
			Name:        "Search Nodes",
			Description: "Search nodes with query parameters",
			Endpoint:    "/api/v1/nodes/search",
			Method:      "POST",
			TestFunc:    func(c *pfclient.Client) (*pfclient.APIResponse, error) {
				return c.SearchNodes(map[string]interface{}{
					"query": map[string]interface{}{
						"limit": 5,
					},
				})
			},
		},
		{
			Name:        "Search Users",
			Description: "Search users with query parameters",
			Endpoint:    "/api/v1/users/search",
			Method:      "POST",
			TestFunc:    func(c *pfclient.Client) (*pfclient.APIResponse, error) {
				return c.SearchUsers(map[string]interface{}{
					"query": map[string]interface{}{
						"limit": 5,
					},
				})
			},
		},
	}
}

// Command definitions for the test suite

var testSuiteCmd = &cobra.Command{
	Use:   "test-suite",
	Short: "Run automated test suite",
	Long:  "Run comprehensive automated test suite with all PacketFence API endpoints",
	Run: func(cmd *cobra.Command, args []string) {
		// Build client config
		config := &pfclient.Config{
			BaseURL:    viper.GetString("url"),
			Username:   viper.GetString("username"),
			Password:   viper.GetString("password"),
			Token:      viper.GetString("token"),
			APIKey:     viper.GetString("api-key"),
			VerifySSL:  viper.GetBool("verify-ssl"),
			Timeout:    time.Duration(viper.GetInt("timeout")) * time.Second,
			MaxRetries: viper.GetInt("max-retries"),
		}
		
		// Create client
		client, err := pfclient.NewClient(config)
		if err != nil {
			fmt.Printf("%s Failed to create client: %v\n", red("✗"), err)
			os.Exit(1)
		}
		
		// Test connection first
		fmt.Printf("%s Connecting to PacketFence API at %s\n", blue("🔗"), config.BaseURL)
		response, err := client.TestConnection()
		if err != nil || !response.Success {
			fmt.Printf("%s Failed to connect to PacketFence API\n", red("❌"))
			if err != nil {
				fmt.Printf("Error: %v\n", err)
			} else {
				fmt.Printf("Error: %s\n", response.Error)
			}
			os.Exit(1)
		}
		
		fmt.Printf("%s Successfully connected to PacketFence API\n", green("✓"))
		
		// Create and run test suite
		testSuite := NewTestSuite(client)
		testCases := generateTestCases()
		testSuite.RunAllTests(testCases)
		
		// Save results if requested
		if saveResults, _ := cmd.Flags().GetBool("save-results"); saveResults {
			timestamp := time.Now().Format("20060102_150405")
			filename := fmt.Sprintf("pf_api_test_results_%s.json", timestamp)
			if outputFile, _ := cmd.Flags().GetString("output"); outputFile != "" {
				filename = outputFile
			}
			
			if err := testSuite.SaveResults(filename); err != nil {
				fmt.Printf("%s Failed to save results: %v\n", red("✗"), err)
			}
		}
		
		// Exit with error code if tests failed
		if len(testSuite.getFailedTests()) > 0 {
			os.Exit(1)
		}
	},
}

func init() {
	// Add test suite specific flags
	testSuiteCmd.Flags().Bool("save-results", true, "Save test results to file")
	testSuiteCmd.Flags().String("output", "", "Output file for results")
	testSuiteCmd.Flags().Duration("delay", 100*time.Millisecond, "Delay between requests")
}

func main() {
	// Create root command for test suite
	var rootCmd = &cobra.Command{
		Use:   "pf-test-suite",
		Short: "PacketFence API Automated Test Suite",
		Long: `Comprehensive automated test suite for PacketFence API.

This tool validates all major API endpoints with automated tests,
performance monitoring, and detailed reporting.`,
	}
	
	// Global flags
	rootCmd.PersistentFlags().String("url", "https://localhost:9999", "PacketFence API base URL")
	rootCmd.PersistentFlags().String("username", "admin", "Username for authentication")
	rootCmd.PersistentFlags().String("password", "admin", "Password for authentication")
	rootCmd.PersistentFlags().String("token", "", "Bearer token for authentication")
	rootCmd.PersistentFlags().String("api-key", "", "API key for authentication")
	rootCmd.PersistentFlags().Bool("verify-ssl", false, "Verify SSL certificates")
	rootCmd.PersistentFlags().Int("timeout", 30, "Request timeout in seconds")
	rootCmd.PersistentFlags().Int("max-retries", 3, "Maximum retry attempts")
	rootCmd.PersistentFlags().String("config", "", "config file (default is $HOME/.pf-test-suite.yaml)")
	
	// Bind flags to viper
	viper.BindPFlags(rootCmd.PersistentFlags())
	viper.AutomaticEnv()
	viper.SetEnvPrefix("PFAPI")
	
	// Add commands
	rootCmd.AddCommand(testSuiteCmd)
	
	// Execute
	if err := rootCmd.Execute(); err != nil {
		log.Fatal(err)
	}
}