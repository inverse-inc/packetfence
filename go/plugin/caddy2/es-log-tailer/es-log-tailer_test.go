package eslogtailer

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"regexp"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

// sampleESDoc returns a sample ECS-formatted ES document
func sampleESDoc(id, timestamp, hostname, syslogName, message, logLevel, process, filename string) map[string]interface{} {
	return map[string]interface{}{
		"@timestamp": timestamp,
		"host": map[string]interface{}{
			"name": hostname,
		},
		"log": map[string]interface{}{
			"level": logLevel,
			"syslog": map[string]interface{}{
				"identifier": syslogName,
			},
			"file": map[string]interface{}{
				"path": filename,
			},
		},
		"process": map[string]interface{}{
			"name": process,
		},
		"message": message,
	}
}

// newMockESServer creates a test HTTP server that mocks ES responses
func newMockESServer(handler http.HandlerFunc) *httptest.Server {
	return httptest.NewServer(handler)
}

func defaultFieldMapping() *ESFieldMapping {
	return &ESFieldMapping{
		Timestamp:        "@timestamp",
		Hostname:         "host.name",
		LogLevel:         "log.level",
		Process:          "process.name",
		SyslogName:       "log.syslog.identifier",
		LogWithoutPrefix: "message",
		Filename:         "log.file.path",
		RawMessage:       "message",
	}
}

func TestESClient_Search(t *testing.T) {
	var receivedBody map[string]interface{}
	var receivedAuth string

	server := newMockESServer(func(w http.ResponseWriter, r *http.Request) {
		// Verify auth
		receivedAuth = r.Header.Get("Authorization")

		// Verify content type
		if ct := r.Header.Get("Content-Type"); ct != "application/json" {
			t.Errorf("expected Content-Type application/json, got %s", ct)
		}

		// Verify method and path
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
						ID: "doc1",
						Source: sampleESDoc("doc1", "2024-01-01T00:00:00Z", "host1", "packetfence", "test message", "info", "pfhttpd", "/var/log/messages"),
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

	resp, err := client.Search(context.Background(), "filebeat-*", query)
	if err != nil {
		t.Fatalf("Search returned error: %v", err)
	}

	// Verify auth header was sent
	if receivedAuth == "" {
		t.Error("expected Authorization header to be set")
	}

	// Verify response parsing
	if len(resp.Hits.Hits) != 1 {
		t.Fatalf("expected 1 hit, got %d", len(resp.Hits.Hits))
	}

	hit := resp.Hits.Hits[0]
	if hit.ID != "doc1" {
		t.Errorf("expected hit ID 'doc1', got '%s'", hit.ID)
	}

	// Verify request body was correct
	if size, ok := receivedBody["size"].(float64); !ok || size != 10 {
		t.Errorf("expected size 10 in request body, got %v", receivedBody["size"])
	}
}

func TestESFieldMapping_ExtractLogMeta(t *testing.T) {
	fm := defaultFieldMapping()

	source := sampleESDoc("doc1", "2024-01-15T10:30:00.123Z", "pf-server-01", "packetfence", "Processing request for MAC 00:11:22:33:44:55", "warn", "pfhttpd", "/var/log/packetfence/packetfence.log")

	meta := fm.ExtractLogMeta(source)

	if meta.Hostname != "pf-server-01" {
		t.Errorf("expected hostname 'pf-server-01', got '%s'", meta.Hostname)
	}
	if meta.LogLevel != "warn" {
		t.Errorf("expected log_level 'warn', got '%s'", meta.LogLevel)
	}
	if meta.Process != "pfhttpd" {
		t.Errorf("expected process 'pfhttpd', got '%s'", meta.Process)
	}
	if meta.SyslogName != "packetfence" {
		t.Errorf("expected syslog_name 'packetfence', got '%s'", meta.SyslogName)
	}
	if meta.LogWithoutPrefix != "Processing request for MAC 00:11:22:33:44:55" {
		t.Errorf("expected log_without_prefix to match, got '%s'", meta.LogWithoutPrefix)
	}
	if meta.Filename != "/var/log/packetfence/packetfence.log" {
		t.Errorf("expected filename '/var/log/packetfence/packetfence.log', got '%s'", meta.Filename)
	}
	if meta.Timestamp.IsZero() {
		t.Error("expected non-zero timestamp")
	}

	raw := fm.GetRawMessage(source)
	if raw != "Processing request for MAC 00:11:22:33:44:55" {
		t.Errorf("expected raw message to match, got '%s'", raw)
	}
}

func TestGetNestedField(t *testing.T) {
	source := map[string]interface{}{
		"host": map[string]interface{}{
			"name": "myhost",
		},
		"log": map[string]interface{}{
			"syslog": map[string]interface{}{
				"identifier": "packetfence",
			},
		},
		"message": "hello world",
	}

	tests := []struct {
		path     string
		expected string
	}{
		{"host.name", "myhost"},
		{"log.syslog.identifier", "packetfence"},
		{"message", "hello world"},
		{"nonexistent.field", ""},
		{"host.nonexistent", ""},
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
						Source: sampleESDoc("hit1", "2024-01-15T10:30:01Z", "host1", "packetfence", "first log line", "info", "pfhttpd", "/var/log/messages"),
						Sort:   []interface{}{"2024-01-15T10:30:01Z", "hit1"},
					},
					{
						ID:     "hit2",
						Source: sampleESDoc("hit2", "2024-01-15T10:30:02Z", "host1", "packetfence", "second log line", "warn", "pfhttpd", "/var/log/messages"),
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
		"filebeat-*",
		"log.syslog.identifier",
	)
	// Set lastTimestamp in the past so the query matches
	session.lastTimestamp = "2024-01-15T10:00:00Z"

	events := session.Poll(context.Background(), client, "test-session", 5*time.Second)

	if len(events) != 2 {
		t.Fatalf("expected 2 events, got %d", len(events))
	}

	// Verify event structure
	event := events[0]
	if event["category"] != "test-session" {
		t.Errorf("expected category 'test-session', got '%v'", event["category"])
	}

	data, ok := event["data"].(gin.H)
	if !ok {
		t.Fatal("expected data to be gin.H")
	}
	if data["raw"] != "first log line" {
		t.Errorf("expected raw 'first log line', got '%v'", data["raw"])
	}

	// Verify cursor was advanced
	if session.lastTimestamp != "2024-01-15T10:30:02Z" {
		t.Errorf("expected lastTimestamp to be '2024-01-15T10:30:02Z', got '%s'", session.lastTimestamp)
	}
	if session.lastSortValues == nil {
		t.Error("expected lastSortValues to be set")
	}

	// Verify ES was only called once (got results on first try)
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
						Source: sampleESDoc("hit1", "2024-01-15T10:30:01Z", "host1", "packetfence", "this matches filter", "info", "pfhttpd", "/var/log/messages"),
						Sort:   []interface{}{"2024-01-15T10:30:01Z", "hit1"},
					},
					{
						ID:     "hit2",
						Source: sampleESDoc("hit2", "2024-01-15T10:30:02Z", "host1", "packetfence", "this does not", "info", "pfhttpd", "/var/log/messages"),
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
		"filebeat-*",
		"log.syslog.identifier",
	)
	session.lastTimestamp = "2024-01-15T10:00:00Z"

	events := session.Poll(context.Background(), client, "test-session", 5*time.Second)

	if len(events) != 1 {
		t.Fatalf("expected 1 event (filtered), got %d", len(events))
	}

	data := events[0]["data"].(gin.H)
	if data["raw"] != "this matches filter" {
		t.Errorf("expected filtered event, got '%v'", data["raw"])
	}

	// Verify cursor advanced past ALL hits (including filtered-out hit2)
	if session.lastTimestamp != "2024-01-15T10:30:02Z" {
		t.Errorf("expected lastTimestamp to advance past filtered hit, got '%s'", session.lastTimestamp)
	}
	if session.lastSortValues == nil {
		t.Error("expected lastSortValues to be set from filtered hit")
	}
}

func TestESTailingSession_Poll_Timeout(t *testing.T) {
	server := newMockESServer(func(w http.ResponseWriter, r *http.Request) {
		// Return empty results
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
		"filebeat-*",
		"log.syslog.identifier",
	)
	session.lastTimestamp = "2024-01-15T10:00:00Z"

	start := time.Now()
	events := session.Poll(context.Background(), client, "test-session", 3*time.Second)
	elapsed := time.Since(start)

	if len(events) != 0 {
		t.Fatalf("expected 0 events on timeout, got %d", len(events))
	}

	// Should have waited approximately the timeout duration
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

	h := newTestHandler(client, fm, "filebeat-*", "log.syslog.identifier")

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

	// Verify sorted alphabetically
	first := allowed[0].(map[string]interface{})
	if first["value"] != "api-frontend" {
		t.Errorf("expected first value 'api-frontend' (sorted), got '%v'", first["value"])
	}
}

func TestHandlers_CreateAndGet(t *testing.T) {
	gin.SetMode(gin.TestMode)

	// Mock ES that returns results on search
	server := newMockESServer(func(w http.ResponseWriter, r *http.Request) {
		resp := ESSearchResponse{
			Hits: ESHits{
				Hits: []ESHit{
					{
						ID:     "doc1",
						Source: sampleESDoc("doc1", "2024-01-15T10:30:01Z", "host1", "packetfence", "test log message", "info", "pfhttpd", "/var/log/messages"),
						Sort:   []interface{}{"2024-01-15T10:30:01Z", "doc1"},
					},
				},
			},
		}
		json.NewEncoder(w).Encode(resp)
	})
	defer server.Close()

	client := NewESClientWithURL(server.URL, "", "")
	fm := defaultFieldMapping()

	h := &ESLogTailerHandler{
		esClient:     client,
		fieldMapping: fm,
		indexPattern: "filebeat-*",
		aggField:     "log.syslog.identifier",
		sessions:     map[string]*ESTailingSession{},
		sessionsLock: &sync.RWMutex{},
	}

	router := gin.New()
	api := router.Group("/api/v1/eslogs/tail")
	api.POST("", h.createNewSession)
	api.GET("/:id", h.getSession)
	api.POST("/:id/touch", h.touchSession)
	api.DELETE("/:id", h.deleteSession)

	// Step 1: Create session
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

	// Step 2: Get events (long-poll) — use short timeout for test
	// We need to set lastTimestamp in the past so our mock hits match
	h.sessionsLock.Lock()
	if session, ok := h.sessions[sessionId]; ok {
		session.mu.Lock()
		session.lastTimestamp = "2024-01-15T10:00:00Z"
		session.mu.Unlock()
	}
	h.sessionsLock.Unlock()

	req = httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/eslogs/tail/%s", sessionId), nil)
	w = httptest.NewRecorder()

	// Run in goroutine since Poll blocks
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
	if data["raw"] != "test log message" {
		t.Errorf("expected raw 'test log message', got '%v'", data["raw"])
	}

	meta := data["meta"].(map[string]interface{})
	if meta["hostname"] != "host1" {
		t.Errorf("expected hostname 'host1', got '%v'", meta["hostname"])
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
