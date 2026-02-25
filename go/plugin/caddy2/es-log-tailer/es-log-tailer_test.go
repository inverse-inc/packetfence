package eslogtailer

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"testing"
	"time"

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
						Sort:   []interface{}{"2024-01-01T00:00:00Z", "doc1"},
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

		// Perl log format
		{"Perl WARN", "-e(12345) WARN: something went wrong", "warn"},
		{"Perl ERROR", "-e(99) ERROR: failed to do thing", "error"},
		{"Perl INFO", "-e(1) INFO: starting up", "info"},
		{"Perl FATAL", "-e(42) FATAL: cannot continue", "fatal"},

		// No log level
		{"No level - plain text", "some random log message", ""},
		{"No level - radius", "(0) Login OK: [bob] (from client nas01)", ""},
		{"Empty message", "", ""},
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

func TestESTailingSession_Poll(t *testing.T) {
	callCount := 0
	server := newMockESServer(func(w http.ResponseWriter, r *http.Request) {
		callCount++
		resp := ESSearchResponse{
			Hits: ESHits{
				Hits: []ESHit{
					{
						ID:     "hit1",
						Source: sampleESDoc("hit1", "2024-01-15T10:30:01Z", "worker-01", "packetfence", "t=2024-01-15T10:30:01+0000 lvl=info msg=\"first log line\""),
						Sort:   []interface{}{"2024-01-15T10:30:01Z", "hit1"},
					},
					{
						ID:     "hit2",
						Source: sampleESDoc("hit2", "2024-01-15T10:30:02Z", "worker-01", "packetfence", "t=2024-01-15T10:30:02+0000 lvl=warn msg=\"second log line\""),
						Sort:   []interface{}{"2024-01-15T10:30:02Z", "hit2"},
					},
				},
			},
		}
		json.NewEncoder(w).Encode(resp)
	})
	defer server.Close()

	client := NewESClientWithURL(server.URL, "", "")
	fm := defaultFieldMapping()

	session := NewESTailingSession(
		[]string{"packetfence"},
		regexp.MustCompile(`.*`),
		fm,
		"prod-*",
		"kubernetes.container_name",
	)

	events := session.Poll(context.Background(), client, "test-session", 5*time.Second)

	if len(events) != 2 {
		t.Fatalf("expected 2 events, got %d", len(events))
	}

	event := events[0]
	if event["category"] != "test-session" {
		t.Errorf("expected category 'test-session', got '%v'", event["category"])
	}

	data, ok := event["data"].(gin.H)
	if !ok {
		t.Fatal("expected data to be gin.H")
	}
	if !strings.Contains(data["raw"].(string), "first log line") {
		t.Errorf("expected raw to contain 'first log line', got '%v'", data["raw"])
	}

	// Verify log level was extracted from message
	meta, ok := data["meta"].(LogMeta)
	if !ok {
		t.Fatal("expected meta to be LogMeta")
	}
	if meta.LogLevel != "info" {
		t.Errorf("expected log level 'info' (from message), got '%s'", meta.LogLevel)
	}

	if session.lastSortValues == nil {
		t.Error("expected lastSortValues to be set")
	}

	if callCount != 1 {
		t.Errorf("expected 1 ES call, got %d", callCount)
	}
}

func TestESTailingSession_Poll_WithFilter(t *testing.T) {
	server := newMockESServer(func(w http.ResponseWriter, r *http.Request) {
		resp := ESSearchResponse{
			Hits: ESHits{
				Hits: []ESHit{
					{
						ID:     "hit1",
						Source: sampleESDoc("hit1", "2024-01-15T10:30:01Z", "worker-01", "packetfence", "this matches filter"),
						Sort:   []interface{}{"2024-01-15T10:30:01Z", "hit1"},
					},
					{
						ID:     "hit2",
						Source: sampleESDoc("hit2", "2024-01-15T10:30:02Z", "worker-01", "packetfence", "this does not"),
						Sort:   []interface{}{"2024-01-15T10:30:02Z", "hit2"},
					},
				},
			},
		}
		json.NewEncoder(w).Encode(resp)
	})
	defer server.Close()

	client := NewESClientWithURL(server.URL, "", "")
	fm := defaultFieldMapping()

	session := NewESTailingSession(
		[]string{"packetfence"},
		regexp.MustCompile(`(?i).*filter.*`),
		fm,
		"prod-*",
		"kubernetes.container_name",
	)

	events := session.Poll(context.Background(), client, "test-session", 5*time.Second)

	if len(events) != 1 {
		t.Fatalf("expected 1 event (filtered), got %d", len(events))
	}

	data := events[0]["data"].(gin.H)
	if data["raw"] != "this matches filter" {
		t.Errorf("expected filtered event, got '%v'", data["raw"])
	}

	if session.lastSortValues == nil {
		t.Error("expected lastSortValues to be set from filtered hit")
	}
}

func TestESTailingSession_Poll_Timeout(t *testing.T) {
	server := newMockESServer(func(w http.ResponseWriter, r *http.Request) {
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

	session := NewESTailingSession(
		[]string{"packetfence"},
		regexp.MustCompile(`.*`),
		fm,
		"prod-*",
		"kubernetes.container_name",
	)

	start := time.Now()
	events := session.Poll(context.Background(), client, "test-session", 3*time.Second)
	elapsed := time.Since(start)

	if len(events) != 0 {
		t.Fatalf("expected 0 events on timeout, got %d", len(events))
	}

	if elapsed < 2*time.Second {
		t.Errorf("expected poll to take at least 2s, took %v", elapsed)
	}
	if elapsed > 5*time.Second {
		t.Errorf("expected poll to take less than 5s, took %v", elapsed)
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

func TestHandlers_CreateAndGet(t *testing.T) {
	gin.SetMode(gin.TestMode)

	callCount := 0
	server := newMockESServer(func(w http.ResponseWriter, r *http.Request) {
		callCount++
		body, _ := io.ReadAll(r.Body)
		var query map[string]interface{}
		json.Unmarshal(body, &query)

		size, _ := query["size"].(float64)
		if size == 1 {
			// SeekToEnd: return the "latest" existing doc
			resp := ESSearchResponse{
				Hits: ESHits{
					Hits: []ESHit{
						{
							ID:     "old-doc",
							Source: sampleESDoc("old-doc", "2024-01-15T10:00:00Z", "worker-01", "packetfence", "t=2024-01-15T10:00:00+0000 lvl=info msg=\"old message\""),
							Sort:   []interface{}{"2024-01-15T10:00:00Z", "old-doc"},
						},
					},
				},
			}
			json.NewEncoder(w).Encode(resp)
		} else {
			// Poll: return a "new" doc
			resp := ESSearchResponse{
				Hits: ESHits{
					Hits: []ESHit{
						{
							ID:     "new-doc",
							Source: sampleESDoc("new-doc", "2024-01-15T10:30:01Z", "worker-01", "packetfence", "t=2024-01-15T10:30:01+0000 lvl=info msg=\"test log message\""),
							Sort:   []interface{}{"2024-01-15T10:30:01Z", "new-doc"},
						},
					},
				},
			}
			json.NewEncoder(w).Encode(resp)
		}
	})
	defer server.Close()

	client := NewESClientWithURL(server.URL, "", "")
	fm := defaultFieldMapping()

	h := &ESLogTailerHandler{
		esClient:     client,
		fieldMapping: fm,
		indexPattern: "prod-*",
		aggField:     "kubernetes.container_name",
		sessions:     map[string]*ESTailingSession{},
		sessionsLock: &sync.RWMutex{},
	}

	router := gin.New()
	api := router.Group("/api/v1/eslogs/tail")
	api.POST("", h.createNewSession)
	api.GET("/:id", h.getSession)
	api.POST("/:id/touch", h.touchSession)
	api.DELETE("/:id", h.deleteSession)

	// Step 1: Create session (triggers SeekToEnd)
	createBody := `{"files":["packetfence"],"filter":"","filter_is_regexp":false}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/eslogs/tail", bytes.NewBufferString(createBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("create: expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	var createResp map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &createResp)

	sessionId, ok := createResp["session_id"].(string)
	if !ok || sessionId == "" {
		t.Fatal("expected session_id in create response")
	}
	if createResp["message"] != "Tailing session started" {
		t.Errorf("expected message 'Tailing session started', got '%v'", createResp["message"])
	}

	if callCount != 1 {
		t.Errorf("expected 1 ES call after create (SeekToEnd), got %d", callCount)
	}

	// Step 2: Get events (long-poll)
	req = httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/eslogs/tail/%s", sessionId), nil)
	w = httptest.NewRecorder()

	done := make(chan struct{})
	go func() {
		router.ServeHTTP(w, req)
		close(done)
	}()

	select {
	case <-done:
	case <-time.After(35 * time.Second):
		t.Fatal("getSession timed out")
	}

	if w.Code != http.StatusOK {
		t.Fatalf("get: expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	var getResp map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &getResp)

	events, ok := getResp["events"].([]interface{})
	if !ok {
		t.Fatal("expected events array in get response")
	}
	if len(events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(events))
	}

	event := events[0].(map[string]interface{})
	if event["category"] != sessionId {
		t.Errorf("expected category '%s', got '%v'", sessionId, event["category"])
	}

	data := event["data"].(map[string]interface{})
	if !strings.Contains(data["raw"].(string), "test log message") {
		t.Errorf("expected raw to contain 'test log message', got '%v'", data["raw"])
	}

	meta := data["meta"].(map[string]interface{})
	if meta["hostname"] != "worker-01" {
		t.Errorf("expected hostname 'worker-01', got '%v'", meta["hostname"])
	}
	if meta["syslog_name"] != "packetfence" {
		t.Errorf("expected syslog_name 'packetfence', got '%v'", meta["syslog_name"])
	}
	// Log level should be extracted from message
	if meta["log_level"] != "info" {
		t.Errorf("expected log_level 'info' (extracted from message), got '%v'", meta["log_level"])
	}

	// Step 3: Touch session
	req = httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/eslogs/tail/%s/touch", sessionId), nil)
	w = httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("touch: expected status 200, got %d", w.Code)
	}

	var touchResp map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &touchResp)
	if touchResp["message"] != "Touched session" {
		t.Errorf("expected message 'Touched session', got '%v'", touchResp["message"])
	}

	// Step 4: Delete session
	req = httptest.NewRequest(http.MethodDelete, fmt.Sprintf("/api/v1/eslogs/tail/%s", sessionId), nil)
	w = httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("delete: expected status 200, got %d", w.Code)
	}

	var deleteResp map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &deleteResp)
	if deleteResp["message"] != "Deleted the session" {
		t.Errorf("expected message 'Deleted the session', got '%v'", deleteResp["message"])
	}

	// Step 5: Verify session is gone
	req = httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/eslogs/tail/%s", sessionId), nil)
	w = httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404 after delete, got %d", w.Code)
	}
}

func TestHandlers_CreateNoFiles(t *testing.T) {
	gin.SetMode(gin.TestMode)

	h := &ESLogTailerHandler{
		sessions:     map[string]*ESTailingSession{},
		sessionsLock: &sync.RWMutex{},
	}

	router := gin.New()
	router.POST("/api/v1/eslogs/tail", h.createNewSession)

	createBody := `{"files":[],"filter":"","filter_is_regexp":false}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/eslogs/tail", bytes.NewBufferString(createBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected status 422, got %d: %s", w.Code, w.Body.String())
	}
}

func TestHandlers_TouchNotFound(t *testing.T) {
	gin.SetMode(gin.TestMode)

	h := &ESLogTailerHandler{
		sessions:     map[string]*ESTailingSession{},
		sessionsLock: &sync.RWMutex{},
	}

	router := gin.New()
	router.POST("/api/v1/eslogs/tail/:id/touch", h.touchSession)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/eslogs/tail/nonexistent/touch", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Fatalf("expected status 404, got %d", w.Code)
	}
}

func TestHandlers_DeleteNotFound(t *testing.T) {
	gin.SetMode(gin.TestMode)

	h := &ESLogTailerHandler{
		sessions:     map[string]*ESTailingSession{},
		sessionsLock: &sync.RWMutex{},
	}

	router := gin.New()
	router.DELETE("/api/v1/eslogs/tail/:id", h.deleteSession)

	req := httptest.NewRequest(http.MethodDelete, "/api/v1/eslogs/tail/nonexistent", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Fatalf("expected status 404, got %d", w.Code)
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
