package detectparser

import (
	"regexp"
	"time"

	cache "github.com/fdurand/go-cache"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

var snortRegexPattern1 = regexp.MustCompile(`(.*?)\[\d+:(\d+):\d+\]\s+(.+?)\s+\[.+?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+){0,1}\s+\-\>\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+){0,1}`)

var snortRegexPattern2 = regexp.MustCompile(`^(.+?)\s+\[\*\*\]\s+\[\d+:(\d+):\d+\]\s+Portscan\s+detected\s+from\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})`)

var snortRegexPattern3 = regexp.MustCompile(`^(.+?)\[\*\*\] \[\d+:(\d+):\d+\]\s+\(spp_portscan2\) Portscan detected from (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})`)

type SnortParser struct {
	Pattern1, Pattern2, Pattern3 *regexp.Regexp
	RateLimit                    *cache.Cache
}

func (s *SnortParser) Parse(line string) ([]ApiCall, error) {
	var dstip, srcip string
	if matches := s.Pattern1.FindStringSubmatch(line); matches != nil {
		dstip, _ = sharedutils.CleanIP(matches[6])
		srcip, _ = sharedutils.CleanIP(matches[4])

		if dstip != "" && srcip != "" {
			return []ApiCall{
				&PfqueueApiCall{
					Method: "event_add",
					Params: []interface{}{
						"date", matches[1],
						"dstip", dstip,
						"srcip", srcip,
						"events", map[string]interface{}{
							"suricata_event": matches[3],
							"detect":         matches[2],
						},
					},
				},
			}, nil
		}
	}

	if matches := s.Pattern2.FindStringSubmatch(line); matches != nil {
		srcip, _ = sharedutils.CleanIP(matches[3])
		if srcip != "" {
			return []ApiCall{
				&PfqueueApiCall{
					Method: "event_add",
					Params: []interface{}{
						"date", matches[1],
						"srcip", srcip,
						"events", map[string]interface{}{
							"detect": "PORTSCAN",
						},
					},
				},
			}, nil
		}
	}

	if matches := s.Pattern3.FindStringSubmatch(line); matches != nil {
		srcip, _ = sharedutils.CleanIP(matches[3])
		if srcip != "" {
			return []ApiCall{
				&PfqueueApiCall{
					Method: "event_add",
					Params: []interface{}{
						"date", matches[1],
						"srcip", srcip,
						"events", map[string]interface{}{
							"detect": "PORTSCAN",
						},
					},
				},
			}, nil
		}
	}

	return nil, nil
}

func NewSnortParser(*PfdetectConfig) (Parser, error) {
	return &SnortParser{
		Pattern1:  snortRegexPattern1.Copy(),
		Pattern2:  snortRegexPattern2.Copy(),
		Pattern3:  snortRegexPattern3.Copy(),
		RateLimit: cache.New(5*time.Second, 10*time.Second),
	}, nil
}
