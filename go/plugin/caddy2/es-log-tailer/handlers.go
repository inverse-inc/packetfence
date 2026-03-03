package eslogtailer

import (
	"context"
	"fmt"
	"net/http"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
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
	l := log.LoggerWContext(ctx)

	resp, err := h.esClient.Search(ctx, h.indexPattern, query)
	if err != nil {
		l.Error(fmt.Sprintf("es-log-tailer OPTIONS: query failed against %s/%s: %s", h.esClient.baseURL, h.indexPattern, err))
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Failed to query Elasticsearch"})
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
	} else {
		l.Warn(fmt.Sprintf("es-log-tailer OPTIONS: aggregation response missing 'sources' key — check that agg_field=%s exists in index_pattern=%s", h.aggField, h.indexPattern))
	}

	if len(files) == 0 {
		l.Warn(fmt.Sprintf("es-log-tailer OPTIONS: 0 sources found — the UI will have no log files to select. Check that index_pattern=%s has documents with agg_field=%s", h.indexPattern, h.aggField))
	} else {
		names := make([]string, 0, len(files))
		for _, f := range files {
			names = append(names, f["value"].(string))
		}
		l.Info(fmt.Sprintf("es-log-tailer OPTIONS: %d sources found: %s", len(files), strings.Join(names, ", ")))
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

func (h *ESLogTailerHandler) pollHandler(c *gin.Context) {
	params := struct {
		Files          []string      `json:"files"`
		Filter         string        `json:"filter"`
		FilterIsRegexp bool          `json:"filter_is_regexp"`
		Cursor         []interface{} `json:"cursor"`
	}{}

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
		var err error
		filterRe, err = regexp.Compile(`(?i)` + params.Filter)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"message": fmt.Sprintf("Invalid regexp: %s", err)})
			return
		}
	} else {
		filterRe = regexp.MustCompile(`(?i).*` + regexp.QuoteMeta(params.Filter) + `.*`)
	}

	sources := normalizeSourceNames(params.Files)
	ctx := c.Request.Context()
	l := log.LoggerWContext(ctx)

	if params.Cursor == nil {
		// No cursor → SeekToEnd
		l.Info(fmt.Sprintf("es-log-tailer POST: SeekToEnd for sources=%v (raw files=%v)", sources, params.Files))
		cursor := h.seekToEnd(ctx, sources)
		c.JSON(http.StatusOK, gin.H{"events": []gin.H{}, "cursor": cursor})
		return
	}

	// With cursor → query for new events
	events, newCursor := h.queryEvents(ctx, sources, filterRe, params.Cursor)
	c.JSON(http.StatusOK, gin.H{"events": events, "cursor": newCursor})
}

// seekToEnd returns the sort values of the latest document for the given sources,
// which serves as the initial cursor for subsequent polls.
func (h *ESLogTailerHandler) seekToEnd(ctx context.Context, sources []string) []interface{} {
	l := log.LoggerWContext(ctx)

	query := map[string]interface{}{
		"size": 1,
		"sort": []interface{}{
			map[string]interface{}{h.fieldMapping.Timestamp: "desc"},
		},
		"query": map[string]interface{}{
			"bool": map[string]interface{}{
				"must": []interface{}{
					map[string]interface{}{
						"terms": map[string]interface{}{
							h.aggField: sources,
						},
					},
				},
			},
		},
	}

	resp, err := h.esClient.Search(ctx, h.indexPattern, query)
	if err != nil {
		cursor := []interface{}{float64(time.Now().UnixMilli())}
		l.Error(fmt.Sprintf("es-log-tailer SeekToEnd: ES query failed for sources=%v index_pattern=%s: %s — falling back to cursor=%v",
			sources, h.indexPattern, err, cursor))
		return cursor
	}

	if len(resp.Hits.Hits) > 0 && len(resp.Hits.Hits[0].Sort) > 0 {
		cursor := resp.Hits.Hits[0].Sort
		l.Info(fmt.Sprintf("es-log-tailer SeekToEnd: found latest doc for sources=%v, cursor=%v", sources, cursor))
		return cursor
	}

	cursor := []interface{}{float64(time.Now().UnixMilli())}
	l.Warn(fmt.Sprintf("es-log-tailer SeekToEnd: 0 documents found for sources=%v in index_pattern=%s (agg_field=%s) — no logs exist for these sources, or the field names are wrong. Falling back to cursor=%v",
		sources, h.indexPattern, h.aggField, cursor))
	return cursor
}

// queryEvents runs a search_after query and returns matching events plus the new cursor.
func (h *ESLogTailerHandler) queryEvents(ctx context.Context, sources []string, filter *regexp.Regexp, cursor []interface{}) ([]gin.H, []interface{}) {
	l := log.LoggerWContext(ctx)

	query := map[string]interface{}{
		"size": 100,
		"sort": []interface{}{
			map[string]interface{}{h.fieldMapping.Timestamp: "asc"},
		},
		"query": map[string]interface{}{
			"bool": map[string]interface{}{
				"must": []interface{}{
					map[string]interface{}{
						"terms": map[string]interface{}{
							h.aggField: sources,
						},
					},
				},
			},
		},
		"search_after": cursor,
	}

	resp, err := h.esClient.Search(ctx, h.indexPattern, query)
	if err != nil {
		l.Error(fmt.Sprintf("es-log-tailer poll: ES query failed for sources=%v cursor=%v: %s", sources, cursor, err))
		return []gin.H{}, cursor
	}

	newCursor := cursor
	var events []gin.H
	emptyRawCount := 0
	filteredOutCount := 0

	for _, hit := range resp.Hits.Hits {
		if len(hit.Sort) > 0 {
			newCursor = hit.Sort
		}

		raw := h.fieldMapping.GetRawMessage(hit.Source)

		if raw == "" {
			emptyRawCount++
		}

		if filter != nil && !filter.MatchString(raw) {
			filteredOutCount++
			continue
		}

		meta := h.fieldMapping.ExtractLogMeta(hit.Source)
		events = append(events, gin.H{
			"timestamp": meta.Timestamp.UnixMilli(),
			"data": gin.H{
				"raw":  raw,
				"meta": meta,
			},
		})
	}

	if events == nil {
		events = []gin.H{}
	}

	esHits := len(resp.Hits.Hits)
	if emptyRawCount > 0 {
		l.Warn(fmt.Sprintf("es-log-tailer poll: %d/%d ES hits had empty raw message — check that field '%s' exists in the documents",
			emptyRawCount, esHits, h.fieldMapping.RawMessage))
	}
	if esHits > 0 && len(events) == 0 && filteredOutCount > 0 {
		l.Warn(fmt.Sprintf("es-log-tailer poll: all %d ES hits were filtered out by filter=%q for sources=%v",
			esHits, filter.String(), sources))
	}

	return events, newCursor
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
	}
	return h
}
