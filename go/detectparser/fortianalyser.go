package detectparser

import (
	"fmt"
	"regexp"

	cache "github.com/fdurand/go-cache"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

var fortiAnalyserRegexPattern1 = regexp.MustCompile(`\s+`)
var fortiAnalyserRegexPattern2 = regexp.MustCompile(`\=`)

type FortiAnalyserParser struct {
	Pattern1, Pattern2 *regexp.Regexp
	RateLimitCache     *cache.Cache
}

func (s *FortiAnalyserParser) Parse(line string) ([]ApiCall, error) {
	matches := s.Pattern1.Split(line, -1)
	var srcip, logid string
	var err error
	for _, str := range matches {
		args := s.Pattern2.Split(str, 2)
		if len(args) <= 1 {
			continue
		}

		if args[0] == "srcip" {
			srcip = args[1]
		} else if args[0] == "logid" {
			logid = args[1]
		}
	}

	if srcip == "" || logid == "" {
		return nil, nil
	}

	if srcip, err = sharedutils.CleanIP(srcip); err != nil {
		return nil, nil
	}

	if s.RateLimitCache != nil {
		rateLimitKey := srcip + ":" + logid
		if _, found := s.RateLimitCache.Get(rateLimitKey); found {
			return nil, fmt.Errorf("Already processed")
		}

		s.RateLimitCache.Set(rateLimitKey, 1, cache.DefaultExpiration)
	}

	return []ApiCall{
		&PfqueueApiCall{
			Method: "event_add",
			Params: []interface{}{
				"srcip", srcip,
				"events", map[string]interface{}{
					"detect": logid,
				},
			},
		},
	}, nil
}

func NewFortiAnalyserParser(config *PfdetectConfig) (Parser, error) {
	return &FortiAnalyserParser{
		Pattern1:       fortiAnalyserRegexPattern1.Copy(),
		Pattern2:       fortiAnalyserRegexPattern2.Copy(),
		RateLimitCache: config.GetCache(),
	}, nil
}
