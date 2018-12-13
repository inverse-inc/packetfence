package detectparser

import (
	"regexp"
	"time"

	cache "github.com/fdurand/go-cache"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

type NexposeParser struct {
	Pattern1  *regexp.Regexp
	RateLimit *cache.Cache
}

func (s *NexposeParser) Parse(line string) ([]ApiCall, error) {
	if matches := s.Pattern1.FindStringSubmatch(line); matches != nil && matches[4] == "VULNERABILITY" {
		dstip, srcip := matches[3], matches[2]
		var err error
		if dstip, err = sharedutils.CleanIP(dstip); err != nil {
			return nil, nil
		}

		if srcip, err = sharedutils.CleanIP(srcip); err != nil {
			return nil, nil
		}

		return []ApiCall{
			&PfqueueApiCall{
				Method: "event_add",
				Params: []interface{}{
					"date", matches[1],
					"dstip", dstip,
					"srcip", srcip,
					"events", map[string]interface{}{
						"nexpose_event": matches[5],
					},
				},
			},
		}, nil
	}

	return nil, nil
}

var nexposeRegexPattern1 = regexp.MustCompile(`^(\w+\s*\d+ \d+:\d+:\d+) ([0-9.]+) \w+: ([0-9.]+) (\w+): (.*)`)

func NewNexposeParser(*PfdetectConfig) (Parser, error) {
	return &NexposeParser{
		Pattern1:  nexposeRegexPattern1.Copy(),
		RateLimit: cache.New(5*time.Second, 10*time.Second),
	}, nil
}
