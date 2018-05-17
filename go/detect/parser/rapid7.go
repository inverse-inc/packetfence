package parser

import (
	"regexp"
)

type Rapid7Parser struct {
	Pattern1 *regexp.Regexp
}

func (s *Rapid7Parser) Parse(line string) ([]ApiCall, error) {
	if matches := s.Pattern1.FindStringSubmatch(line); matches != nil && matches[4] == "VULNERABILITY" {
		return []ApiCall{
			&JsonRpcApiCall{
				Method: "event_add",
				Params: []interface{}{
					"date", matches[1],
					"dstip", matches[3],
					"srcip", matches[2],
					"events", map[string]interface{}{
						"nexpose_event": matches[5],
					},
				},
			},
		}, nil
	}
	return []ApiCall{}, nil
}

var rapid7RegexPattern1 = regexp.MustCompile(`^(\w+\s*\d+ \d+:\d+:\d+) ([0-9.]+) \w+: ([0-9.]+) (\w+): (.*)`)

func NewRapid7Parser(interface{}) (Parser, error) {
	return &Rapid7Parser{
		Pattern1: rapid7RegexPattern1.Copy(),
	}, nil
}
