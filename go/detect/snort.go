package detect

import (
	"fmt"
	"regexp"
)

//var snortRegexPattern1 = regexp.MustCompile(`^(.*?)\[\d+:(\d+):\d+\]\s+(.+?)\s+\[.+?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+){0,1}\s+\-\>\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+){0,1}`)
var snortRegexPattern1 = regexp.MustCompile(`(.*?)\[\d+:(\d+):\d+\]\s+(.+?)\s+\[.+?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+){0,1}\s+\-\>\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+){0,1}`)

var snortRegexPattern2 = regexp.MustCompile(`^(.+?)\s+\[\*\*\]\s+\[\d+:(\d+):\d+\]\s+Portscan\s+detected\s+from\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})`)

var snortRegexPattern3 = regexp.MustCompile(`^(.+?)\[\*\*\] \[\d+:(\d+):\d+\]\s+\(spp_portscan2\) Portscan detected from (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})`)

type SnortParser struct {
	Pattern1, Pattern2, Pattern3 *regexp.Regexp
}

func (s *SnortParser) Parse(line string) ([]ApiCall, error) {
	if matches := s.Pattern1.FindStringSubmatch(line); matches != nil {
		return []ApiCall{
			&JsonRpcApiCall{
				Method: "event_add",
				Params: []interface{}{
					"date", matches[1],
					"dstip", matches[6],
					"srcip", matches[4],
					"events", map[string]interface{}{
						"suricata_event": matches[3],
						"detect":         matches[2],
					},
				},
			},
		}, nil
	}

	if matches := s.Pattern2.FindStringSubmatch(line); matches != nil {
		return []ApiCall{
			&JsonRpcApiCall{
				Method: "event_add",
				Params: []interface{}{
					"date", matches[1],
					"srcip", matches[3],
					"events", map[string]interface{}{
						"detect": "PORTSCAN",
					},
				},
			},
		}, nil
	}

	if matches := s.Pattern3.FindStringSubmatch(line); matches != nil {
		return []ApiCall{
			&JsonRpcApiCall{
				Method: "event_add",
				Params: []interface{}{
					"date", matches[1],
					"srcip", matches[3],
					"events", map[string]interface{}{
						"detect": "PORTSCAN",
					},
				},
			},
		}, nil
	}

	return nil, fmt.Errorf("Error parsing")
}

func NewSnortParser() Parser {
	return &SnortParser{
		Pattern1: snortRegexPattern1.Copy(),
		Pattern2: snortRegexPattern2.Copy(),
		Pattern3: snortRegexPattern3.Copy(),
	}
}
