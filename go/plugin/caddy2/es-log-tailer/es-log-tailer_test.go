package eslogtailer

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/inverse-inc/go-utils/log"
)

// sampleESDoc returns a sample ES document matching production kubernetes field structure
func sampleESDoc(id, timestamp, host, containerName, message string) map[string]interface{} {
	return map[string]interface{}{
		"timestamp": timestamp,
		"stream":    "stdout",
		"message":   message,
		"kubernetes": map[string]interface{}{
			"container_name": containerName,
			"host":           host,
			"namespace_name": "pfk8s-test",
			"pod_name":       containerName + "-abc123",
			"pod_id":         "00000000-0000-0000-0000-000000000000",
		},
	}
}

// newMockESServer creates a test HTTP server that mocks ES responses
func newMockESServer(handler http.HandlerFunc) *httptest.Server {
	return httptest.NewServer(handler)
}

func defaultFieldMapping() *ESFieldMapping {
	return &ESFieldMapping{
		Timestamp:        "timestamp",
		Hostname:         "kubernetes.host",
		LogLevel:         "",
		Process:          "kubernetes.container_name",
		SyslogName:       "kubernetes.container_name",
		LogWithoutPrefix: "message",
		Filename:         "",
		RawMessage:       "message",
	}
}

func TestESClient_Search(t *testing.T) {
	var receivedBody map[string]interface{}
	var receivedAuth string

	server := newMockESServer(func(w http.ResponseWriter, r *http.Request) {
		receivedAuth = r.Header.Get("Authorization")

		if ct := r.Header.Get("Content-Type"); ct != "application/json" {
			t.Errorf("expected Content-Type application/json, got %s", ct)
		}

		if r.Method != http.MethodPost {
			t.Errorf("expected POST, got %s", r.Method)
		}
		if !strings.Contains(r.URL.Path, "/_search") {
			t.Errorf("expected path to contain /_search, got %s", r.URL.Path)
		}

		body, _ := io.ReadAll(r.Body)
		json.Unmarshal(body, &receivedBody)

		resp := ESSearchResponse{
			Hits: ESHits{
				Hits: []ESHit{
					{
						ID:     "doc1",
						Source: sampleESDoc("doc1", "2024-01-01T00:00:00Z", "worker-01", "packetfence", "t=2024-01-01T00:00:00+0000 lvl=info msg=\"test message\""),
						Sort:   []interface{}{float64(1704067200000)},
					},
				},
			},
		}
		json.NewEncoder(w).Encode(resp)
	})
	defer server.Close()

	client := NewESClientWithURL(server.URL, "testuser", "testpass")
	query := map[string]interface{}{
		"size": 10,
		"query": map[string]interface{}{
			"match_all": map[string]interface{}{},
		},
	}

	resp, err := client.Search(context.Background(), "prod-*", query)
	if err != nil {
		t.Fatalf("Search returned error: %v", err)
	}

	if receivedAuth == "" {
		t.Error("expected Authorization header to be set")
	}

	if len(resp.Hits.Hits) != 1 {
		t.Fatalf("expected 1 hit, got %d", len(resp.Hits.Hits))
	}

	hit := resp.Hits.Hits[0]
	if hit.ID != "doc1" {
		t.Errorf("expected hit ID 'doc1', got '%s'", hit.ID)
	}

	if size, ok := receivedBody["size"].(float64); !ok || size != 10 {
		t.Errorf("expected size 10 in request body, got %v", receivedBody["size"])
	}
}

func TestESFieldMapping_ExtractLogMeta(t *testing.T) {
	fm := defaultFieldMapping()

	source := sampleESDoc("doc1", "2024-01-15T10:30:00.123Z", "worker-01", "api-frontend", "t=2024-01-15T10:30:00+0000 lvl=warn msg=\"401 POST /api/v1/login\"")

	meta := fm.ExtractLogMeta(source)

	if meta.Hostname != "worker-01" {
		t.Errorf("expected hostname 'worker-01', got '%s'", meta.Hostname)
	}
	// Log level extracted from message (no log.level field in production)
	if meta.LogLevel != "warn" {
		t.Errorf("expected log_level 'warn' (extracted from message), got '%s'", meta.LogLevel)
	}
	if meta.Process != "api-frontend" {
		t.Errorf("expected process 'api-frontend', got '%s'", meta.Process)
	}
	if meta.SyslogName != "api-frontend" {
		t.Errorf("expected syslog_name 'api-frontend', got '%s'", meta.SyslogName)
	}
	// Filename falls back to SyslogName when ES_FIELD_FILENAME is empty
	if meta.Filename != "api-frontend" {
		t.Errorf("expected filename to fallback to syslog_name 'api-frontend', got '%s'", meta.Filename)
	}
	if meta.Timestamp.IsZero() {
		t.Error("expected non-zero timestamp")
	}

	raw := fm.GetRawMessage(source)
	if !strings.Contains(raw, "lvl=warn") {
		t.Errorf("expected raw message to contain 'lvl=warn', got '%s'", raw)
	}
}

func TestExtractLogLevelFromMessage(t *testing.T) {
	tests := []struct {
		name     string
		message  string
		expected string
	}{
		// Go log format
		{"Go info", "t=2024-01-15T10:30:00+0000 lvl=info msg=\"test\"", "info"},
		{"Go warn", "t=2024-01-15T10:30:00+0000 lvl=warn msg=\"warning\"", "warn"},
		{"Go error", "t=2024-01-15T10:30:00+0000 lvl=eror msg=\"error\"", "error"},
		{"Go debug", "t=2024-01-15T10:30:00+0000 lvl=dbug msg=\"debug\"", "debug"},
		{"Go trace", "t=2024-01-15T10:30:00+0000 lvl=trce msg=\"trace\"", "trace"},

		// Perl -e format
		{"Perl WARN", "-e(12345) WARN: something went wrong", "warn"},
		{"Perl ERROR", "-e(99) ERROR: failed to do thing", "error"},
		{"Perl INFO", "-e(1) INFO: starting up", "info"},
		{"Perl FATAL", "-e(42) FATAL: cannot continue", "fatal"},

		// PF httpd format: httpd.<name>(<pid>) LEVEL: message
		{"httpd.portal WARN", "httpd.portal(120) WARN: [mac:unknown] Unable to match MAC address to IP '10.48.9.51' (pf::ip4log::ip2mac)", "warn"},
		{"httpd.aaa INFO", "httpd.aaa(7) INFO: [mac:[undef]] handling radius autz request", "info"},
		{"httpd.portal WARN 2", "httpd.portal(48) WARN: [mac:unknown] Unable to match MAC address", "warn"},
		{"httpd.portal ERROR", "httpd.portal(61) ERROR: something failed", "error"},

		// FreeRADIUS format: <Day Mon DD HH:MM:SS YYYY> : <Level>: <message>
		{"FreeRADIUS Error", "Sun Mar  1 02:02:19 2026 : Error: !!!!!!!!!!!!!!!!!", "error"},
		{"FreeRADIUS Error 2", "Mon Mar  2 14:03:39 2026 : Error: BlastRADIUS check: Received packet without Proxy-State.", "error"},
		{"FreeRADIUS Warning", "Tue Jan  7 08:15:30 2025 : Warning: something is degraded", "warning"},
		{"FreeRADIUS Info", "Wed Feb 12 10:00:00 2025 : Info: server started", "info"},

		// Plain prefix: message starts with level keyword
		{"pfconfig error", "error reading from socket", "error"},
		{"pfconfig error2", "error from client at 10.48.0.1:44240", "error"},
		{"warn prefix", "warning: disk space low", "warn"},

		// Default to info when no structured level is found
		{"default - plain text", "some random log message", "info"},
		{"default - radius login", "(0) Login OK: [bob] (from client nas01)", "info"},
		{"default - apache access", `- - - [02/Mar/2026:22:58:56 +0000] "GET /captive-portal HTTP/1.0" 200 4999`, "info"},
		{"default - erroreous not a prefix", "erroreous should not match", "info"},
		{"Empty message", "", "info"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := extractLogLevelFromMessage(tt.message)
			if result != tt.expected {
				t.Errorf("extractLogLevelFromMessage(%q) = %q, want %q", tt.message, result, tt.expected)
			}
		})
	}
}

func TestGetNestedField(t *testing.T) {
	source := map[string]interface{}{
		"kubernetes": map[string]interface{}{
			"container_name": "api-frontend",
			"host":           "worker-01",
			"namespace_name": "pfk8s-test",
		},
		"message": "hello world",
	}

	tests := []struct {
		path     string
		expected string
	}{
		{"kubernetes.host", "worker-01"},
		{"kubernetes.container_name", "api-frontend"},
		{"kubernetes.namespace_name", "pfk8s-test"},
		{"message", "hello world"},
		{"nonexistent.field", ""},
		{"kubernetes.nonexistent", ""},
		{"", ""},
	}

	for _, tt := range tests {
		t.Run(tt.path, func(t *testing.T) {
			result := getNestedFieldString(source, tt.path)
			if result != tt.expected {
				t.Errorf("getNestedFieldString(%q) = %q, want %q", tt.path, result, tt.expected)
			}
		})
	}
}

func TestHandlers_Options(t *testing.T) {
	gin.SetMode(gin.TestMode)

	server := newMockESServer(func(w http.ResponseWriter, r *http.Request) {
		resp := ESSearchResponse{
			Aggregations: map[string]ESAggregation{
				"sources": {
					Buckets: []ESBucket{
						{Key: "packetfence", DocCount: 100},
						{Key: "api-frontend", DocCount: 50},
						{Key: "pfhttpd", DocCount: 25},
					},
				},
			},
		}
		json.NewEncoder(w).Encode(resp)
	})
	defer server.Close()

	client := NewESClientWithURL(server.URL, "", "")
	fm := defaultFieldMapping()

	h := newTestHandler(client, fm, "prod-*", "kubernetes.container_name")

	router := gin.New()
	router.OPTIONS("/api/v1/eslogs/tail", h.optionsSessions)

	req := httptest.NewRequest(http.MethodOptions, "/api/v1/eslogs/tail", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	var result map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &result)

	meta, ok := result["meta"].(map[string]interface{})
	if !ok {
		t.Fatal("expected meta in response")
	}

	files, ok := meta["files"].(map[string]interface{})
	if !ok {
		t.Fatal("expected files in meta")
	}

	item, ok := files["item"].(map[string]interface{})
	if !ok {
		t.Fatal("expected item in files")
	}

	allowed, ok := item["allowed"].([]interface{})
	if !ok {
		t.Fatal("expected allowed in item")
	}

	if len(allowed) != 3 {
		t.Fatalf("expected 3 allowed values, got %d", len(allowed))
	}

	first := allowed[0].(map[string]interface{})
	if first["value"] != "api-frontend" {
		t.Errorf("expected first value 'api-frontend' (sorted), got '%v'", first["value"])
	}
}

func TestPoll_NoCursor_SeekToEnd(t *testing.T) {
	gin.SetMode(gin.TestMode)

	server := newMockESServer(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var query map[string]interface{}
		json.Unmarshal(body, &query)

		// SeekToEnd: size=1, sort desc
		resp := ESSearchResponse{
			Hits: ESHits{
				Hits: []ESHit{
					{
						ID:     "latest-doc",
						Source: sampleESDoc("latest-doc", "2024-01-15T10:00:00Z", "worker-01", "packetfence", "latest message"),
						Sort:   []interface{}{float64(1705311600000)},
					},
				},
			},
		}
		json.NewEncoder(w).Encode(resp)
	})
	defer server.Close()

	client := NewESClientWithURL(server.URL, "", "")
	fm := defaultFieldMapping()
	h := newTestHandler(client, fm, "prod-*", "kubernetes.container_name")

	router := gin.New()
	router.POST("/api/v1/eslogs/tail", h.pollHandler)

	body := `{"files":["packetfence"],"filter":"","filter_is_regexp":false}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/eslogs/tail", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &resp)

	events, ok := resp["events"].([]interface{})
	if !ok {
		t.Fatal("expected events array")
	}
	if len(events) != 0 {
		t.Errorf("expected 0 events on SeekToEnd, got %d", len(events))
	}

	cursor, ok := resp["cursor"].([]interface{})
	if !ok {
		t.Fatal("expected cursor array")
	}
	if len(cursor) != 1 {
		t.Fatalf("expected cursor with 1 element, got %d", len(cursor))
	}
	if cursor[0].(float64) != float64(1705311600000) {
		t.Errorf("expected cursor [1705311600000], got %v", cursor)
	}
}

func TestPoll_WithCursor_ReturnsEvents(t *testing.T) {
	gin.SetMode(gin.TestMode)

	callCount := 0
	server := newMockESServer(func(w http.ResponseWriter, r *http.Request) {
		callCount++
		body, _ := io.ReadAll(r.Body)
		var query map[string]interface{}
		json.Unmarshal(body, &query)

		// Verify search_after is present
		if _, ok := query["search_after"]; !ok {
			t.Error("expected search_after in query")
		}

		resp := ESSearchResponse{
			Hits: ESHits{
				Hits: []ESHit{
					{
						ID:     "new-doc",
						Source: sampleESDoc("new-doc", "2024-01-15T10:30:01Z", "worker-01", "packetfence", "t=2024-01-15T10:30:01+0000 lvl=info msg=\"test log message\""),
						Sort:   []interface{}{float64(1705312201000)},
					},
				},
			},
		}
		json.NewEncoder(w).Encode(resp)
	})
	defer server.Close()

	client := NewESClientWithURL(server.URL, "", "")
	fm := defaultFieldMapping()
	h := newTestHandler(client, fm, "prod-*", "kubernetes.container_name")

	router := gin.New()
	router.POST("/api/v1/eslogs/tail", h.pollHandler)

	body := `{"files":["packetfence"],"filter":"","filter_is_regexp":false,"cursor":[1705311600000]}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/eslogs/tail", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &resp)

	events, ok := resp["events"].([]interface{})
	if !ok {
		t.Fatal("expected events array")
	}
	if len(events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(events))
	}

	event := events[0].(map[string]interface{})
	data := event["data"].(map[string]interface{})
	if !strings.Contains(data["raw"].(string), "test log message") {
		t.Errorf("expected raw to contain 'test log message', got '%v'", data["raw"])
	}

	meta := data["meta"].(map[string]interface{})
	if meta["hostname"] != "worker-01" {
		t.Errorf("expected hostname 'worker-01', got '%v'", meta["hostname"])
	}
	if meta["log_level"] != "info" {
		t.Errorf("expected log_level 'info', got '%v'", meta["log_level"])
	}

	// Verify cursor advanced
	cursor := resp["cursor"].([]interface{})
	if cursor[0].(float64) != float64(1705312201000) {
		t.Errorf("expected cursor to advance to 1705312201000, got %v", cursor[0])
	}

	if callCount != 1 {
		t.Errorf("expected 1 ES call, got %d", callCount)
	}
}

func TestPoll_WithFilter(t *testing.T) {
	gin.SetMode(gin.TestMode)

	server := newMockESServer(func(w http.ResponseWriter, r *http.Request) {
		resp := ESSearchResponse{
			Hits: ESHits{
				Hits: []ESHit{
					{
						ID:     "hit1",
						Source: sampleESDoc("hit1", "2024-01-15T10:30:01Z", "worker-01", "packetfence", "this matches filter"),
						Sort:   []interface{}{float64(1705312201000)},
					},
					{
						ID:     "hit2",
						Source: sampleESDoc("hit2", "2024-01-15T10:30:02Z", "worker-01", "packetfence", "this does not"),
						Sort:   []interface{}{float64(1705312202000)},
					},
				},
			},
		}
		json.NewEncoder(w).Encode(resp)
	})
	defer server.Close()

	client := NewESClientWithURL(server.URL, "", "")
	fm := defaultFieldMapping()
	h := newTestHandler(client, fm, "prod-*", "kubernetes.container_name")

	router := gin.New()
	router.POST("/api/v1/eslogs/tail", h.pollHandler)

	body := `{"files":["packetfence"],"filter":"filter","filter_is_regexp":false,"cursor":[1705311600000]}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/eslogs/tail", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &resp)

	events := resp["events"].([]interface{})
	if len(events) != 1 {
		t.Fatalf("expected 1 event (filtered), got %d", len(events))
	}

	event := events[0].(map[string]interface{})
	data := event["data"].(map[string]interface{})
	if data["raw"] != "this matches filter" {
		t.Errorf("expected filtered event, got '%v'", data["raw"])
	}

	// Cursor should advance past both hits (including filtered-out one)
	cursor := resp["cursor"].([]interface{})
	if cursor[0].(float64) != float64(1705312202000) {
		t.Errorf("expected cursor to advance past all hits to 1705312202000, got %v", cursor[0])
	}
}

func TestPoll_NoFiles_Returns422(t *testing.T) {
	gin.SetMode(gin.TestMode)

	h := newTestHandler(nil, nil, "prod-*", "kubernetes.container_name")

	router := gin.New()
	router.POST("/api/v1/eslogs/tail", h.pollHandler)

	body := `{"files":[],"filter":"","filter_is_regexp":false}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/eslogs/tail", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected status 422, got %d: %s", w.Code, w.Body.String())
	}
}

func TestPoll_NoCursor_EmptyIndex(t *testing.T) {
	gin.SetMode(gin.TestMode)

	server := newMockESServer(func(w http.ResponseWriter, r *http.Request) {
		// Empty index — no hits
		resp := ESSearchResponse{
			Hits: ESHits{
				Hits: []ESHit{},
			},
		}
		json.NewEncoder(w).Encode(resp)
	})
	defer server.Close()

	client := NewESClientWithURL(server.URL, "", "")
	fm := defaultFieldMapping()
	h := newTestHandler(client, fm, "prod-*", "kubernetes.container_name")

	router := gin.New()
	router.POST("/api/v1/eslogs/tail", h.pollHandler)

	body := `{"files":["packetfence"],"filter":"","filter_is_regexp":false}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/eslogs/tail", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &resp)

	events := resp["events"].([]interface{})
	if len(events) != 0 {
		t.Errorf("expected 0 events on empty index, got %d", len(events))
	}

	// Cursor must be non-null even with no docs — prevents infinite SeekToEnd loop
	cursor, ok := resp["cursor"].([]interface{})
	if !ok || cursor == nil {
		t.Fatal("expected non-null cursor even for empty index")
	}
	if len(cursor) != 1 {
		t.Fatalf("expected cursor with 1 element, got %d", len(cursor))
	}
	ts, ok := cursor[0].(float64)
	if !ok || ts <= 0 {
		t.Errorf("expected positive timestamp in cursor, got %v", cursor[0])
	}
}

func TestPoll_NoCursor_ESError(t *testing.T) {
	gin.SetMode(gin.TestMode)

	server := newMockESServer(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
		w.Write([]byte(`{"error":"cluster unavailable"}`))
	})
	defer server.Close()

	client := NewESClientWithURL(server.URL, "", "")
	fm := defaultFieldMapping()
	h := newTestHandler(client, fm, "prod-*", "kubernetes.container_name")

	router := gin.New()
	router.POST("/api/v1/eslogs/tail", h.pollHandler)

	body := `{"files":["packetfence"],"filter":"","filter_is_regexp":false}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/eslogs/tail", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &resp)

	// Even on ES error, cursor must be non-null so client doesn't loop
	cursor, ok := resp["cursor"].([]interface{})
	if !ok || cursor == nil {
		t.Fatal("expected non-null cursor even on ES error")
	}
	ts, ok := cursor[0].(float64)
	if !ok || ts <= 0 {
		t.Errorf("expected positive timestamp in cursor, got %v", cursor[0])
	}
}

func TestBuildHandler_K8SNamespaceFromPath(t *testing.T) {
	dir := t.TempDir()
	nsFile := filepath.Join(dir, "namespace")
	os.WriteFile(nsFile, []byte("pfk8s-abc123\n"), 0644)

	t.Setenv("K8S_NAMESPACE_PATH", nsFile)
	t.Setenv("KIBANA_HOST", "localhost")
	t.Setenv("ES_AGG_FIELD", "")

	m := &ESLogTailerHandler{}
	ctx := log.LoggerNewContext(context.Background())
	err := m.buildHandler(ctx)
	if err != nil {
		t.Fatalf("buildHandler returned error: %v", err)
	}

	if m.indexPattern != "prod-pfk8s-abc123-*" {
		t.Errorf("expected indexPattern 'prod-pfk8s-abc123-*', got '%s'", m.indexPattern)
	}
	if m.router == nil {
		t.Error("expected router to be initialized")
	}
}

func TestBuildHandler_EmptyNamespaceFile_Disabled(t *testing.T) {
	dir := t.TempDir()
	nsFile := filepath.Join(dir, "namespace")
	os.WriteFile(nsFile, []byte("  \n"), 0644)

	t.Setenv("K8S_NAMESPACE_PATH", nsFile)
	t.Setenv("KIBANA_HOST", "localhost")

	m := &ESLogTailerHandler{}
	ctx := log.LoggerNewContext(context.Background())
	err := m.buildHandler(ctx)
	if err != nil {
		t.Fatalf("buildHandler returned error: %v", err)
	}

	if m.router != nil {
		t.Error("expected router to be nil when namespace file is empty (plugin disabled)")
	}
}

func TestBuildHandler_NoNamespacePath_Disabled(t *testing.T) {
	t.Setenv("K8S_NAMESPACE_PATH", "")
	t.Setenv("KIBANA_HOST", "localhost")

	m := &ESLogTailerHandler{}
	ctx := log.LoggerNewContext(context.Background())
	err := m.buildHandler(ctx)
	if err != nil {
		t.Fatalf("buildHandler returned error: %v", err)
	}

	if m.router != nil {
		t.Error("expected router to be nil when namespace is not set (plugin disabled)")
	}
	if m.indexPattern != "" {
		t.Errorf("expected empty indexPattern, got '%s'", m.indexPattern)
	}
}

func TestBuildHandler_BadNamespacePath_Disabled(t *testing.T) {
	// /dev/null reads as empty, which hits the "empty namespace" path
	t.Setenv("K8S_NAMESPACE_PATH", "/dev/null")
	t.Setenv("KIBANA_HOST", "localhost")

	m := &ESLogTailerHandler{}
	ctx := log.LoggerNewContext(context.Background())
	err := m.buildHandler(ctx)
	if err != nil {
		t.Fatalf("buildHandler returned error: %v", err)
	}

	if m.router != nil {
		t.Error("expected router to be nil when namespace file is empty (plugin disabled)")
	}
}

func TestBuildHandler_NoKibanaHost_Disabled(t *testing.T) {
	dir := t.TempDir()
	nsFile := filepath.Join(dir, "namespace")
	os.WriteFile(nsFile, []byte("pfk8s-test\n"), 0644)

	t.Setenv("K8S_NAMESPACE_PATH", nsFile)
	t.Setenv("KIBANA_HOST", "")

	m := &ESLogTailerHandler{}
	ctx := log.LoggerNewContext(context.Background())
	err := m.buildHandler(ctx)
	if err != nil {
		t.Fatalf("buildHandler returned error: %v", err)
	}

	if m.router != nil {
		t.Error("expected router to be nil when KIBANA_HOST is missing (plugin disabled)")
	}
}

func TestBuildHandler_NothingSet_Disabled(t *testing.T) {
	t.Setenv("K8S_NAMESPACE_PATH", "")
	t.Setenv("KIBANA_HOST", "")

	m := &ESLogTailerHandler{}
	ctx := log.LoggerNewContext(context.Background())
	err := m.buildHandler(ctx)
	if err != nil {
		t.Fatalf("buildHandler returned error: %v", err)
	}

	if m.router != nil {
		t.Error("expected router to be nil when no env vars set (plugin disabled)")
	}
}
