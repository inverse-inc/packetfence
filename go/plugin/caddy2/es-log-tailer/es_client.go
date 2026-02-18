package eslogtailer

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

type ESClient struct {
	baseURL    string
	username   string
	password   string
	httpClient *http.Client
}

type ESSearchResponse struct {
	Hits         ESHits                    `json:"hits"`
	Aggregations map[string]ESAggregation  `json:"aggregations"`
}

type ESHits struct {
	Hits []ESHit `json:"hits"`
}

type ESHit struct {
	ID     string                 `json:"_id"`
	Source map[string]interface{} `json:"_source"`
	Sort   []interface{}          `json:"sort"`
}

type ESAggregation struct {
	Buckets []ESBucket `json:"buckets"`
}

type ESBucket struct {
	Key      string `json:"key"`
	DocCount int    `json:"doc_count"`
}

func NewESClient() *ESClient {
	host := os.Getenv("KIBANA_HOST")
	port := os.Getenv("KIBANA_PORT")
	if port == "" {
		port = "9200"
	}
	scheme := os.Getenv("KIBANA_SCHEME")
	if scheme == "" {
		scheme = "https"
	}

	return &ESClient{
		baseURL:  fmt.Sprintf("%s://%s:%s", scheme, host, port),
		username: os.Getenv("KIBANA_USER"),
		password: os.Getenv("KIBANA_PASS"),
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
			},
		},
	}
}

func NewESClientWithURL(baseURL, username, password string) *ESClient {
	return &ESClient{
		baseURL:  baseURL,
		username: username,
		password: password,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
			},
		},
	}
}

func (c *ESClient) Search(ctx context.Context, index string, body interface{}) (*ESSearchResponse, error) {
	jsonBody, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request body: %w", err)
	}

	url := fmt.Sprintf("%s/%s/_search", c.baseURL, index)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(jsonBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if c.username != "" {
		req.SetBasicAuth(c.username, c.password)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("ES request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("ES returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var result ESSearchResponse
	if err := json.Unmarshal(respBody, &result); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	return &result, nil
}
