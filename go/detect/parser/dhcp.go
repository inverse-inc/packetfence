package parser

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
	if matches := s.Pattern1.FindStringSubmatch(line); matches != nil && matches[1] == "DHCPACK" {
		return []ApiCall{
			&JsonRpcApiCall{
				Method: "update_ip4log",
				Params: []interface{}{
					"mac", matches[3],
					"ip", matches[2],
				},
			},
		}, nil
	}

	if matches := s.Pattern2.FindStringSubmatch(line); matches != nil && matches[1] == "DHCPACK" {
		return []ApiCall{
			&JsonRpcApiCall{
				Method: "update_ip4log",
				Params: []interface{}{
					"mac", matches[3],
					"ip", matches[2],
				},
			},
		}, nil
	}

	return nil, fmt.Errorf("Error parsing")
}

func NewDhcpParser() Parser {
	return &DhcpParser{
		Pattern1: dhcpRegexPattern1.Copy(),
		Pattern2: dhcpRegexPattern2.Copy(),
	}
}
