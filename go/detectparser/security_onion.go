package detectparser

import (
	"fmt"
	"regexp"
	"time"

	cache "github.com/fdurand/go-cache"
)

var securityOnionRegexPattern1 = regexp.MustCompile(` {|} `)

var securityOnionRegexPattern2 = regexp.MustCompile(` `)

type SecurityOnionParser struct {
	Pattern1, Pattern2 *regexp.Regexp
	RateLimit          *cache.Cache
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

	if _, found := s.RateLimit.Get(matches2[0] + matches1[1] + matches2[3]); found {
		return nil, fmt.Errorf("Already processed")
	}
	s.RateLimit.Set(matches2[0]+matches1[1]+matches2[3], 1, time.Duration(1)*time.Second)
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

func NewSecurityOnionParser(*PfdetectConfig) (Parser, error) {
	return &SecurityOnionParser{
		Pattern1:  securityOnionRegexPattern1.Copy(),
		Pattern2:  securityOnionRegexPattern2.Copy(),
		RateLimit: cache.New(5*time.Second, 10*time.Second),
	}, nil
}
