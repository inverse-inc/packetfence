package eslogtailer

import (
	"context"
	"regexp"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

const pollSleepInterval = 2 * time.Second

type ESTailingSession struct {
	sources        []string
	filter         *regexp.Regexp
	lastSortValues []interface{}
	lastTimestamp  string
	fieldMapping   *ESFieldMapping
	indexPattern   string
	aggField       string
	lastUsedAt     time.Time
	mu             sync.Mutex
}

func NewESTailingSession(sources []string, filter *regexp.Regexp, fieldMapping *ESFieldMapping, indexPattern, aggField string) *ESTailingSession {
	return &ESTailingSession{
		sources:       sources,
		filter:        filter,
		lastTimestamp: time.Now().UTC().Format(time.RFC3339Nano),
		fieldMapping:  fieldMapping,
		indexPattern:  indexPattern,
		aggField:      aggField,
		lastUsedAt:    time.Now(),
	}
}

func (s *ESTailingSession) Touch() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.lastUsedAt = time.Now()
}

func (s *ESTailingSession) LastUsedAt() time.Time {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.lastUsedAt
}

func (s *ESTailingSession) Poll(ctx context.Context, client *ESClient, sessionId string, timeout time.Duration) []gin.H {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.lastUsedAt = time.Now()
	deadline := time.Now().Add(timeout)

	for time.Now().Before(deadline) {
		query := s.buildQuery()
		resp, err := client.Search(ctx, s.indexPattern, query)
		if err != nil {
			// On error, sleep and retry until timeout
			if !sleepUntil(ctx, pollSleepInterval, deadline) {
				break
			}
			continue
		}

		if len(resp.Hits.Hits) > 0 {
			events := s.processHits(resp.Hits.Hits, sessionId)
			if len(events) > 0 {
				return events
			}
		}

		if !sleepUntil(ctx, pollSleepInterval, deadline) {
			break
		}
	}

	return []gin.H{}
}

func (s *ESTailingSession) buildQuery() map[string]interface{} {
	must := []interface{}{
		map[string]interface{}{
			"range": map[string]interface{}{
				s.fieldMapping.Timestamp: map[string]interface{}{
					"gte": s.lastTimestamp,
				},
			},
		},
	}

	if len(s.sources) > 0 {
		must = append(must, map[string]interface{}{
			"terms": map[string]interface{}{
				s.aggField: s.sources,
			},
		})
	}

	query := map[string]interface{}{
		"size": 100,
		"query": map[string]interface{}{
			"bool": map[string]interface{}{
				"must": must,
			},
		},
		"sort": []interface{}{
			map[string]interface{}{s.fieldMapping.Timestamp: "asc"},
			map[string]interface{}{"_id": "asc"},
		},
	}

	if s.lastSortValues != nil {
		query["search_after"] = s.lastSortValues
	}

	return query
}

func (s *ESTailingSession) processHits(hits []ESHit, sessionId string) []gin.H {
	var events []gin.H

	for _, hit := range hits {
		// Always advance cursor, even for filtered-out hits,
		// to keep lastSortValues in sync with lastTimestamp.
		if len(hit.Sort) > 0 {
			s.lastSortValues = hit.Sort
		}

		raw := s.fieldMapping.GetRawMessage(hit.Source)

		// Apply filter
		if s.filter != nil && !s.filter.MatchString(raw) {
			continue
		}

		meta := s.fieldMapping.ExtractLogMeta(hit.Source)
		event := gin.H{
			"timestamp": meta.Timestamp.UnixMilli(),
			"category":  sessionId,
			"data": gin.H{
				"raw":  raw,
				"meta": meta,
			},
		}
		events = append(events, event)
	}

	// Update lastTimestamp from the last hit
	if len(hits) > 0 {
		lastHit := hits[len(hits)-1]
		if ts := getNestedFieldString(lastHit.Source, s.fieldMapping.Timestamp); ts != "" {
			s.lastTimestamp = ts
		}
	}

	return events
}

func sleepUntil(ctx context.Context, d time.Duration, deadline time.Time) bool {
	remaining := time.Until(deadline)
	if remaining <= 0 {
		return false
	}
	if d > remaining {
		d = remaining
	}

	select {
	case <-time.After(d):
		return true
	case <-ctx.Done():
		return false
	}
}
