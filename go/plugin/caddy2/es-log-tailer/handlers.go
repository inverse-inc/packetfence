package eslogtailer

import (
	"fmt"
	"net/http"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/inverse-inc/go-utils/log"
)

func (h *ESLogTailerHandler) optionsSessions(c *gin.Context) {
	query := map[string]interface{}{
		"size": 0,
		"aggs": map[string]interface{}{
			"sources": map[string]interface{}{
				"terms": map[string]interface{}{
					"field": h.aggField,
					"size":  1000,
				},
			},
		},
	}

	ctx := c.Request.Context()
	resp, err := h.esClient.Search(ctx, h.indexPattern, query)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("es-log-tailer: OPTIONS query failed against %s/%s: %s", h.esClient.baseURL, h.indexPattern, err))
		c.JSON(http.StatusInternalServerError, gin.H{"message": fmt.Sprintf("Failed to query Elasticsearch: %s", err)})
		return
	}

	files := []gin.H{}
	if agg, ok := resp.Aggregations["sources"]; ok {
		buckets := agg.Buckets
		sort.Slice(buckets, func(i, j int) bool {
			return buckets[i].Key < buckets[j].Key
		})
		for _, bucket := range buckets {
			files = append(files, gin.H{"text": bucket.Key, "value": bucket.Key})
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"meta": gin.H{
			"filter": gin.H{
				"type":        "string",
				"required":    false,
				"default":     nil,
				"placeholder": nil,
			},
			"filter_is_regexp": gin.H{
				"type":        "string",
				"required":    false,
				"default":     nil,
				"placeholder": false,
			},
			"files": gin.H{
				"type":        "array",
				"required":    true,
				"placeholder": nil,
				"default":     nil,
				"item": gin.H{
					"type":        "string",
					"required":    true,
					"placeholder": nil,
					"default":     nil,
					"allowed":     files,
				},
			},
		},
	})
}

func (h *ESLogTailerHandler) createNewSession(c *gin.Context) {
	h.sessionsLock.Lock()
	defer h.sessionsLock.Unlock()

	params := struct {
		Files          []string `json:"files"`
		Filter         string   `json:"filter"`
		FilterIsRegexp bool     `json:"filter_is_regexp"`
	}{}

	sessionId := uuid.New().String()

	if err := c.ShouldBindJSON(&params); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Unable to parse JSON payload"})
		return
	}

	if len(params.Files) == 0 {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"message": "No files were specified"})
		return
	}

	var filterRe *regexp.Regexp
	if params.Filter == "" {
		filterRe = regexp.MustCompile(`.*`)
	} else if params.FilterIsRegexp {
		filterRe = regexp.MustCompile(`(?i)` + params.Filter)
	} else {
		filterRe = regexp.MustCompile(`(?i).*` + regexp.QuoteMeta(params.Filter) + `.*`)
	}

	// Normalize file paths to container names: "/usr/local/pf/logs/api-frontend.log" → "api-frontend"
	sources := normalizeSourceNames(params.Files)

	ctx := c.Request.Context()
	log.LoggerWContext(ctx).Info(fmt.Sprintf("es-log-tailer: creating session %s, sources=%v, filter=%q, regexp=%v", sessionId, sources, params.Filter, params.FilterIsRegexp))

	session := NewESTailingSession(sources, filterRe, h.fieldMapping, h.indexPattern, h.aggField)
	session.SeekToEnd(ctx, h.esClient)
	h.sessions[sessionId] = session

	c.JSON(http.StatusOK, gin.H{"message": "Tailing session started", "session_id": sessionId})
}

func (h *ESLogTailerHandler) getSession(c *gin.Context) {
	sessionId := c.Param("id")

	h.sessionsLock.RLock()
	session, ok := h.sessions[sessionId]
	h.sessionsLock.RUnlock()

	if !ok {
		c.JSON(http.StatusNotFound, gin.H{"message": "Unable to find a session with this identifier"})
		return
	}

	ctx := c.Request.Context()
	events := session.Poll(ctx, h.esClient, sessionId, defaultPollTimeout)

	c.JSON(http.StatusOK, gin.H{"events": events})
}

func (h *ESLogTailerHandler) touchSession(c *gin.Context) {
	h.sessionsLock.RLock()
	defer h.sessionsLock.RUnlock()

	sessionId := c.Param("id")

	session, ok := h.sessions[sessionId]
	if !ok {
		c.JSON(http.StatusNotFound, gin.H{"message": "Unable to find a session with this identifier"})
		return
	}

	session.Touch()

	c.JSON(http.StatusOK, gin.H{"message": "Touched session"})
}

func (h *ESLogTailerHandler) deleteSession(c *gin.Context) {
	h.sessionsLock.Lock()
	defer h.sessionsLock.Unlock()

	ctx := c.Request.Context()
	sessionId := c.Param("id")
	if _, ok := h.sessions[sessionId]; ok {
		delete(h.sessions, sessionId)
		log.LoggerWContext(ctx).Info("es-log-tailer: deleted session " + sessionId)
		c.JSON(http.StatusOK, gin.H{"message": "Deleted the session"})
	} else {
		c.JSON(http.StatusNotFound, gin.H{"message": "Unable to find this session"})
	}
}

// normalizeSourceNames converts file paths to container names.
// If a source looks like a path (contains "/"), the base name is extracted
// and common log extensions are stripped:
//
//	"/usr/local/pf/logs/api-frontend.log" → "api-frontend"
//	"api-frontend" → "api-frontend" (unchanged)
func normalizeSourceNames(sources []string) []string {
	out := make([]string, 0, len(sources))
	for _, s := range sources {
		if strings.Contains(s, "/") {
			s = filepath.Base(s)
			s = strings.TrimSuffix(s, ".log")
		}
		if s != "" {
			out = append(out, s)
		}
	}
	return out
}

// newTestHandler creates a minimal handler for testing with the given client
func newTestHandler(client *ESClient, fieldMapping *ESFieldMapping, indexPattern, aggField string) *ESLogTailerHandler {
	h := &ESLogTailerHandler{
		esClient:     client,
		fieldMapping: fieldMapping,
		indexPattern: indexPattern,
		aggField:     aggField,
		sessions:     map[string]*ESTailingSession{},
		sessionsLock: &sync.RWMutex{},
	}
	return h
}

