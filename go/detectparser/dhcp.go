package detectparser

import (
	"fmt"
	"regexp"
)

var dhcpRegexPattern1 = regexp.MustCompile(`(DHCPDISCOVER|DHCPOFFER|DHCPREQUEST|DHCPACK|DHCPRELEASE|DHCPINFORM|DHCPEXPIRE) on ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) to ([0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2})`)

var dhcpRegexPattern2 = regexp.MustCompile(`(DHCPDISCOVER|DHCPOFFER|DHCPREQUEST|DHCPACK|DHCPRELEASE|DHCPINFORM|DHCPEXPIRE) to ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) \(([0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2})\)`)

type DhcpParser struct {
	Pattern1, Pattern2 *regexp.Regexp
}

func (s *DhcpParser) Parse(line string) ([]ApiCall, error) {
	for _, r := range []*regexp.Regexp{s.Pattern1, s.Pattern2} {
		if matches := r.FindStringSubmatch(line); matches != nil && matches[1] == "DHCPACK" {
			return []ApiCall{
				&PfqueueApiCall{
					Method: "update_ip4log",
					Params: []interface{}{
						"mac", matches[3],
						"ip", matches[2],
					},
				},
			}, nil
		}
	}

	return nil, fmt.Errorf("Error parsing")
}

func NewDhcpParser(*PfdetectConfig) (Parser, error) {
	return &DhcpParser{
		Pattern1: dhcpRegexPattern1.Copy(),
		Pattern2: dhcpRegexPattern2.Copy(),
	}, nil
}
