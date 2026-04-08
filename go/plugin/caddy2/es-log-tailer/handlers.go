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
		l.Warn(fmt.Sprintf("es-log-tailer OPTIONS: 0 sources found — check index_pattern=%s agg_field=%s", h.indexPattern, h.aggField))
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
		Files          []string    `json:"files"`
		Filter         string      `json:"filter"`
		FilterIsRegexp bool        `json:"filter_is_regexp"`
		Cursor         interface{} `json:"cursor"`
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

	cursorMap, ok := params.Cursor.(map[string]interface{})
	if !ok || cursorMap == nil {
		cursor := h.seekToEnd(ctx, sources)
		c.JSON(http.StatusOK, gin.H{"events": []gin.H{}, "cursor": cursor})
		return
	}

	// With cursor → query for new events
	events, newCursor := h.queryEvents(ctx, sources, filterRe, cursorMap)
	c.JSON(http.StatusOK, gin.H{"events": events, "cursor": newCursor})
}

// seekToEnd returns a per-source cursor map where each source has the sort value
// of its latest document. This ensures clock-skewed sources don't block others.
func (h *ESLogTailerHandler) seekToEnd(ctx context.Context, sources []string) map[string]interface{} {
	l := log.LoggerWContext(ctx)

	query := map[string]interface{}{
		"size": 0,
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
		"aggs": map[string]interface{}{
			"per_source": map[string]interface{}{
				"terms": map[string]interface{}{
					"field": h.aggField,
					"size":  1000,
				},
				"aggs": map[string]interface{}{
					"latest": map[string]interface{}{
						"top_hits": map[string]interface{}{
							"size":    1,
							"sort":    []interface{}{map[string]interface{}{h.fieldMapping.Timestamp: "desc"}},
							"_source": false,
						},
					},
				},
			},
		},
	}

	resp, err := h.esClient.Search(ctx, h.indexPattern, query)
	if err != nil {
		// Aggregation failed — try a simpler query to get an ES-derived timestamp
		// instead of using time.Now() which may be affected by local clock skew.
		l.Error(fmt.Sprintf("es-log-tailer SeekToEnd: ES agg query failed for sources=%v index_pattern=%s: %s — trying fallback",
			sources, h.indexPattern, err))
		cursor := make(map[string]interface{}, len(sources))
		var fallback interface{}
		if ts, ok := h.getLatestTimestamp(ctx); ok {
			fallback = ts
		} else {
			l.Warn("es-log-tailer SeekToEnd: fallback timestamp query also failed — using local time (may be skewed)")
			fallback = float64(time.Now().UnixMilli())
		}
		for _, src := range sources {
			cursor[src] = fallback
		}
		return cursor
	}

	cursor := make(map[string]interface{}, len(sources))
	if agg, ok := resp.Aggregations["per_source"]; ok {
		for _, bucket := range agg.Buckets {
			if bucket.Latest != nil && len(bucket.Latest.Hits.Hits) > 0 && len(bucket.Latest.Hits.Hits[0].Sort) > 0 {
				cursor[bucket.Key] = bucket.Latest.Hits.Hits[0].Sort[0]
			}
		}
	}

	// For sources not found in aggregation results, use the max cursor from
	// found sources as a proxy for "ES current time". This avoids using
	// time.Now() which may be skewed on the api-frontend pod.
	unfound := 0
	for _, src := range sources {
		if _, ok := cursor[src]; !ok {
			unfound++
		}
	}
	if unfound > 0 {
		var fallback interface{}
		if maxTs, ok := maxCursorTs(cursor); ok {
			fallback = maxTs
		} else if ts, ok := h.getLatestTimestamp(ctx); ok {
			fallback = ts
		} else {
			l.Warn("es-log-tailer SeekToEnd: no ES-derived timestamp available — using local time (may be skewed)")
			fallback = float64(time.Now().UnixMilli())
		}
		for _, src := range sources {
			if _, ok := cursor[src]; !ok {
				cursor[src] = fallback
				l.Warn(fmt.Sprintf("es-log-tailer SeekToEnd: no documents found for source=%s, using ES-derived cursor", src))
			}
		}
	}

	return cursor
}

// queryEvents runs a per-source range query and returns matching events plus the updated cursor.
func (h *ESLogTailerHandler) queryEvents(ctx context.Context, sources []string, filter *regexp.Regexp, cursor map[string]interface{}) ([]gin.H, map[string]interface{}) {
	l := log.LoggerWContext(ctx)

	// Build per-source should clauses with individual range filters
	shouldClauses := make([]interface{}, 0, len(sources))
	// Pre-compute a fallback timestamp from the cursor map so we never
	// depend on the local clock (which may be skewed in K8s).
	var fallbackTs interface{}
	if maxTs, ok := maxCursorTs(cursor); ok {
		fallbackTs = maxTs
	} else if ts, ok := h.getLatestTimestamp(ctx); ok {
		fallbackTs = ts
	} else {
		l.Warn("es-log-tailer queryEvents: no ES-derived timestamp available — using local time (may be skewed)")
		fallbackTs = float64(time.Now().UnixMilli())
	}

	for _, src := range sources {
		ts, ok := cursor[src]
		if !ok {
			ts = fallbackTs
		}
		shouldClauses = append(shouldClauses, map[string]interface{}{
			"bool": map[string]interface{}{
				"must": []interface{}{
					map[string]interface{}{
						"term": map[string]interface{}{
							h.aggField: src,
						},
					},
					map[string]interface{}{
						"range": map[string]interface{}{
							h.fieldMapping.Timestamp: map[string]interface{}{
								"gt": ts,
							},
						},
					},
				},
			},
		})
	}

	query := map[string]interface{}{
		"size": 100,
		"sort": []interface{}{
			map[string]interface{}{h.fieldMapping.Timestamp: "asc"},
		},
		"query": map[string]interface{}{
			"bool": map[string]interface{}{
				"should":               shouldClauses,
				"minimum_should_match": 1,
			},
		},
	}

	resp, err := h.esClient.Search(ctx, h.indexPattern, query)
	if err != nil {
		l.Error(fmt.Sprintf("es-log-tailer poll: ES query failed for sources=%v cursor=%v: %s", sources, cursor, err))
		return []gin.H{}, cursor
	}

	// Copy cursor so we can update per-source values
	newCursor := make(map[string]interface{}, len(cursor))
	for k, v := range cursor {
		newCursor[k] = v
	}

	sourceField := strings.TrimSuffix(h.aggField, ".keyword")
	var events []gin.H
	emptyRawCount := 0
	filteredOutCount := 0

	for _, hit := range resp.Hits.Hits {
		// Update per-source cursor from each hit
		sourceName := getNestedFieldString(hit.Source, sourceField)
		if sourceName != "" && len(hit.Sort) > 0 {
			newCursor[sourceName] = hit.Sort[0]
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
// If a source looks like an absolute path (starts with "/"), the base name
// is extracted and common log extensions are stripped:
//
//	"/usr/local/pf/logs/api-frontend.log" → "api-frontend"
//	"api-frontend" → "api-frontend" (unchanged)
func normalizeSourceNames(sources []string) []string {
	out := make([]string, 0, len(sources))
	for _, s := range sources {
		if strings.HasPrefix(s, "/") {
			s = filepath.Base(s)
			s = strings.TrimSuffix(s, ".log")
		}
		if s != "" {
			out = append(out, s)
		}
	}
	return out
}

// maxCursorTs returns the maximum float64 timestamp found in the cursor map.
// This serves as a proxy for "ES current time" and avoids depending on the
// local system clock which may be skewed.
func maxCursorTs(cursor map[string]interface{}) (float64, bool) {
	var max float64
	found := false
	for _, v := range cursor {
		if ts, ok := v.(float64); ok {
			if !found || ts > max {
				max = ts
				found = true
			}
		}
	}
	return max, found
}

// getLatestTimestamp queries ES for the most recent document's sort value
// across the entire index pattern (not filtered to specific sources).
// This provides an ES-derived timestamp independent of the local system clock.
func (h *ESLogTailerHandler) getLatestTimestamp(ctx context.Context) (interface{}, bool) {
	query := map[string]interface{}{
		"size": 1,
		"sort": []interface{}{
			map[string]interface{}{h.fieldMapping.Timestamp: "desc"},
		},
	}
	resp, err := h.esClient.Search(ctx, h.indexPattern, query)
	if err == nil && len(resp.Hits.Hits) > 0 && len(resp.Hits.Hits[0].Sort) > 0 {
		return resp.Hits.Hits[0].Sort[0], true
	}
	return nil, false
}

