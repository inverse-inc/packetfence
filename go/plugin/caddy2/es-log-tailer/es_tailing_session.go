package eslogtailer

import (
	"context"
	"fmt"
	"regexp"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/inverse-inc/go-utils/log"
)

const pollSleepInterval = 2 * time.Second

type ESTailingSession struct {
	// Immutable after construction
	sources      []string
	filter       *regexp.Regexp
	fieldMapping *ESFieldMapping
	indexPattern  string
	aggField     string

	// Mutable — protected by mu
	lastSortValues []interface{}
	mu             sync.Mutex

	// Atomic — no lock needed
	lastUsedAt atomic.Int64 // Unix nanoseconds

	// Semaphore — prevents concurrent polls on the same session
	pollSem chan struct{}
}

func NewESTailingSession(sources []string, filter *regexp.Regexp, fieldMapping *ESFieldMapping, indexPattern, aggField string) *ESTailingSession {
	s := &ESTailingSession{
		sources:      sources,
		filter:       filter,
		fieldMapping: fieldMapping,
		indexPattern: indexPattern,
		aggField:     aggField,
		pollSem:      make(chan struct{}, 1),
	}
	s.lastUsedAt.Store(time.Now().UnixNano())
	return s
}

// SeekToEnd queries ES for the latest document matching the session's sources
// and positions the cursor after it, like SEEK_END for file tailing.
func (s *ESTailingSession) SeekToEnd(ctx context.Context, client *ESClient) {
	must := []interface{}{}
	if len(s.sources) > 0 {
		must = append(must, map[string]interface{}{
			"terms": map[string]interface{}{
				s.aggField: s.sources,
			},
		})
	}

	query := map[string]interface{}{
		"size": 1,
		"sort": []interface{}{
			map[string]interface{}{s.fieldMapping.Timestamp: "desc"},
		},
	}
	if len(must) > 0 {
		query["query"] = map[string]interface{}{
			"bool": map[string]interface{}{"must": must},
		}
	}

	resp, err := client.Search(ctx, s.indexPattern, query)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("es-log-tailer: SeekToEnd failed for sources=%v: %s", s.sources, err))
		return
	}
	if len(resp.Hits.Hits) == 0 {
		log.LoggerWContext(ctx).Info(fmt.Sprintf("es-log-tailer: SeekToEnd found no documents for sources=%v in index %s", s.sources, s.indexPattern))
		return
	}

	// Position cursor at the latest doc so subsequent polls only return new docs.
	s.mu.Lock()
	s.lastSortValues = resp.Hits.Hits[0].Sort
	s.mu.Unlock()
}

func (s *ESTailingSession) Touch() {
	s.lastUsedAt.Store(time.Now().UnixNano())
}

func (s *ESTailingSession) LastUsedAt() time.Time {
	return time.Unix(0, s.lastUsedAt.Load())
}

func (s *ESTailingSession) Poll(ctx context.Context, client *ESClient, sessionId string, timeout time.Duration) []gin.H {
	// Only one poll at a time per session
	select {
	case s.pollSem <- struct{}{}:
		defer func() { <-s.pollSem }()
	default:
		return []gin.H{}
	}

	s.Touch()
	deadline := time.Now().Add(timeout)

	for time.Now().Before(deadline) {
		// Read cursor under lock
		s.mu.Lock()
		query := s.buildQuery()
		s.mu.Unlock()

		// ES query outside lock
		resp, err := client.Search(ctx, s.indexPattern, query)
		if err != nil {
			log.LoggerWContext(ctx).Error(fmt.Sprintf("es-log-tailer: poll query failed for session %s: %s", sessionId, err))
			if !sleepUntil(ctx, pollSleepInterval, deadline) {
				break
			}
			continue
		}

		if len(resp.Hits.Hits) > 0 {
			// Update cursor under lock
			s.mu.Lock()
			events := s.processHits(resp.Hits.Hits, sessionId)
			s.mu.Unlock()
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
	query := map[string]interface{}{
		"size": 100,
		"sort": []interface{}{
			map[string]interface{}{s.fieldMapping.Timestamp: "asc"},
		},
	}

	if len(s.sources) > 0 {
		query["query"] = map[string]interface{}{
			"bool": map[string]interface{}{
				"must": []interface{}{
					map[string]interface{}{
						"terms": map[string]interface{}{
							s.aggField: s.sources,
						},
					},
				},
			},
		}
	}

	if s.lastSortValues != nil {
		query["search_after"] = s.lastSortValues
	}

	return query
}

func (s *ESTailingSession) processHits(hits []ESHit, sessionId string) []gin.H {
	var events []gin.H

	for _, hit := range hits {
		// Always advance cursor, even for filtered-out hits.
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
