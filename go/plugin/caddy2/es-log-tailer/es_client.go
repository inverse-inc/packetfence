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

	"github.com/inverse-inc/go-utils/log"
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
	Key      string        `json:"key"`
	DocCount int           `json:"doc_count"`
	Latest   *ESTopHitsAgg `json:"latest,omitempty"`
}

type ESTopHitsAgg struct {
	Hits ESHits `json:"hits"`
}

func NewESClient() *ESClient {
	host := os.Getenv("KIBANA_HOST")
	scheme := os.Getenv("KIBANA_SCHEME")
	if scheme == "" {
		scheme = "https"
	}

	skipVerify := os.Getenv("KIBANA_TLS_SKIP_VERIFY") != "false"

	return &ESClient{
		baseURL:  fmt.Sprintf("%s://%s:9200", scheme, host),
		username: os.Getenv("KIBANA_USER"),
		password: os.Getenv("KIBANA_PASS"),
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{InsecureSkipVerify: skipVerify},
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

	log.LoggerWContext(ctx).Debug(fmt.Sprintf("es-log-tailer ES request: POST %s body=%s", url, string(jsonBody)))

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("ES request POST %s failed: %w", url, err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body from %s: %w", url, err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("ES returned status %d from POST %s: %s", resp.StatusCode, url, string(respBody))
	}

	var result ESSearchResponse
	if err := json.Unmarshal(respBody, &result); err != nil {
		return nil, fmt.Errorf("failed to unmarshal ES response from %s: %w (body: %.500s)", url, err, string(respBody))
	}

	return &result, nil
}
