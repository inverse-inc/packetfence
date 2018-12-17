package detectparser

import (
	"fmt"
	"regexp"

	cache "github.com/fdurand/go-cache"
)

var securityOnionRegexPattern1 = regexp.MustCompile(` {|} `)

var securityOnionRegexPattern2 = regexp.MustCompile(` `)

type SecurityOnionParser struct {
	Pattern1, Pattern2 *regexp.Regexp
	RateLimitCache     *cache.Cache
}

func (s *SecurityOnionParser) Parse(line string) ([]ApiCall, error) {

	matches1 := s.Pattern1.Split(line, -1)
	if len(matches1) != 5 {
		return nil, fmt.Errorf("Error parsing")
	}

	matches2 := s.Pattern2.Split(matches1[4], -1)
	if len(matches2) != 10 {
		return nil, fmt.Errorf("Error parsing")
	}

	if s.RateLimitCache != nil {
		rateLimitKey := matches2[0] + matches1[1] + matches2[3]
		if _, found := s.RateLimitCache.Get(rateLimitKey); found {
			return nil, fmt.Errorf("Already processed")
		}

		s.RateLimitCache.Set(rateLimitKey, 1, cache.DefaultExpiration)
	}

	return []ApiCall{
		&PfqueueApiCall{
			Method: "event_add",
			Params: []interface{}{
				"date", matches1[1],
				"srcip", matches2[0],
				"dstip", matches2[1],
				"events", map[string]interface{}{
					"suricata_event": matches1[3],
					"detect":         matches2[6],
				},
			},
		},
	}, nil
}

func NewSecurityOnionParser(config *PfdetectConfig) (Parser, error) {

	return &SecurityOnionParser{
		Pattern1:       securityOnionRegexPattern1.Copy(),
		Pattern2:       securityOnionRegexPattern2.Copy(),
		RateLimitCache: config.GetCache(),
	}, nil
}
