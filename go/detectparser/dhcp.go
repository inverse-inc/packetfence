package detectparser

import (
	"regexp"
	"time"

	cache "github.com/fdurand/go-cache"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

var dhcpRegexPattern1 = regexp.MustCompile(`(DHCPDISCOVER|DHCPOFFER|DHCPREQUEST|DHCPACK|DHCPRELEASE|DHCPINFORM|DHCPEXPIRE) on ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) to ([0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2})`)

var dhcpRegexPattern2 = regexp.MustCompile(`(DHCPDISCOVER|DHCPOFFER|DHCPREQUEST|DHCPACK|DHCPRELEASE|DHCPINFORM|DHCPEXPIRE) to ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) \(([0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2})\)`)

type DhcpParser struct {
	Pattern1, Pattern2 *regexp.Regexp
	RateLimit          *cache.Cache
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

			return []ApiCall{
				&PfqueueApiCall{
					Method: "update_ip4log",
					Params: []interface{}{
						"mac", mac,
						"ip", ip,
					},
				},
			}, nil
		}
	}

	return nil, nil
}

func NewDhcpParser(*PfdetectConfig) (Parser, error) {
	return &DhcpParser{
		Pattern1:  dhcpRegexPattern1.Copy(),
		Pattern2:  dhcpRegexPattern2.Copy(),
		RateLimit: cache.New(5*time.Second, 10*time.Second),
	}, nil
}
