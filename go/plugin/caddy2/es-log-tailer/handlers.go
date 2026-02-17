package eslogtailer

import (
	"fmt"
	"net/http"
	"regexp"
	"sort"
	"sync"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
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

	resp, err := h.esClient.Search(c.Request.Context(), h.indexPattern, query)
	if err != nil {
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

	h.sessions[sessionId] = NewESTailingSession(params.Files, filterRe, h.fieldMapping, h.indexPattern, h.aggField)

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

	sessionId := c.Param("id")
	if _, ok := h.sessions[sessionId]; ok {
		delete(h.sessions, sessionId)
		c.JSON(http.StatusOK, gin.H{"message": "Deleted the session"})
	} else {
		c.JSON(http.StatusNotFound, gin.H{"message": "Unable to find this session"})
	}
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

