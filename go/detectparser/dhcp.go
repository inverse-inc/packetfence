package detectparser

import (
	"regexp"
	"strings"

	"github.com/inverse-inc/go-utils/sharedutils"
)

// The hostname in parentheses is only logged when the client sent one (option 12)
var dhcpRegexPattern1 = regexp.MustCompile(`(DHCPDISCOVER|DHCPOFFER|DHCPREQUEST|DHCPACK|DHCPRELEASE|DHCPINFORM|DHCPEXPIRE) on ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) to ([0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2})(?: \(([^)]*)\))?`)

var dhcpRegexPattern2 = regexp.MustCompile(`(DHCPDISCOVER|DHCPOFFER|DHCPREQUEST|DHCPACK|DHCPRELEASE|DHCPINFORM|DHCPEXPIRE) to ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) \(([0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2})\)`)

type DhcpParser struct {
	Pattern1, Pattern2 *regexp.Regexp
	parser
}

func (s *DhcpParser) Parse(line string) ([]ApiCall, error) {
	for _, r := range []*regexp.Regexp{s.Pattern1, s.Pattern2} {
		if matches := r.FindStringSubmatch(line); matches != nil && matches[1] == "DHCPACK" {
			ip, err := sharedutils.CleanIP(matches[2])
			if err != nil {
				continue
			}

			mac := sharedutils.CleanMac(matches[3])
			if mac == "" {
				continue
			}

			if err := s.NotRateLimited(mac + ":" + ip); err != nil {
				return nil, err
			}

			apiCalls := []ApiCall{
				&PfqueueApiCall{
					Method: "update_ip4log",
					Params: []interface{}{
						"mac", mac,
						"ip", ip,
					},
				},
			}

			// Only the "DHCPACK on <ip> to <mac> (<hostname>)" format carries a hostname
			if len(matches) > 4 {
				if hostname := strings.TrimSpace(matches[4]); hostname != "" {
					apiCalls = append(apiCalls, &PfqueueApiCall{
						Method: "modify_node",
						Params: []interface{}{
							"mac", mac,
							"computername", hostname,
						},
					})
				}
			}

			return apiCalls, nil
		}
	}

	return nil, nil
}

func NewDhcpParser(config *PfdetectConfig) (Parser, error) {
	return &DhcpParser{
		Pattern1: dhcpRegexPattern1.Copy(),
		Pattern2: dhcpRegexPattern2.Copy(),
		parser:   setupParser(config),
	}, nil
}
