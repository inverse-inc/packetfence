package logtailer

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/jcuga/golongpoll"
)

func TestGetSessionUnknownIdentifier(t *testing.T) {
	gin.SetMode(gin.TestMode)
	manager, err := golongpoll.StartLongpoll(golongpoll.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer manager.Shutdown()

	h := &LogTailerHandler{
		eventsManager: manager,
		sessions:      map[string]*TailingSession{},
		sessionsLock:  &sync.RWMutex{},
	}

	router := gin.New()
	router.GET("/api/v1/logs/tail/:id", h.getSession)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, httptest.NewRequest("GET", "/api/v1/logs/tail/unknown", nil))

	if w.Code != http.StatusNotFound {
		t.Errorf("Expected a 404, got %d", w.Code)
	}

	// The body must be a single JSON document (the long poll handler must not run)
	var reply map[string]interface{}
	decoder := json.NewDecoder(w.Body)
	if err := decoder.Decode(&reply); err != nil {
		t.Fatalf("Unable to decode the reply: %s", err)
	}
	if decoder.More() {
		t.Errorf("The reply contains more than one JSON document: %s", w.Body.String())
	}
}
