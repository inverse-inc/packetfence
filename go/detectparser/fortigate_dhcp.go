package detectparser

import (
	"errors"
	"regexp"
	"strings"

	"github.com/inverse-inc/go-utils/sharedutils"
)

var fortiGateDhcpRegexPattern1 = regexp.MustCompile(`(\w+)="([^"]*)"|(\w+)=([^\s]+)`)

type FortiGateDhcpParser struct {
	Pattern1 *regexp.Regexp
	parser
}

func (s *FortiGateDhcpParser) Parse(line string) ([]ApiCall, error) {
	matches := s.Pattern1.FindAllStringSubmatch(line, -1)
	var mac, ip, lease, hostname, ack string
	var err error

	attributes := make(map[string]string)
	hostname = "N/A"
	for _, match := range matches {
		if match[1] != "" {
			attributes[match[1]] = match[2]
		} else {
			attributes[match[3]] = match[4]
		}
	}

	if value, ok := attributes["mac"]; ok {
		mac = strings.ToLower(value)
	}
	if value, ok := attributes["ip"]; ok {
		ip = value
	}
	if value, ok := attributes["lease"]; ok {
		lease = value
	}
	if value, ok := attributes["hostname"]; ok {
		hostname = value
	}
	if value, ok := attributes["dhcp_msg"]; ok {
		ack = value
	}

	if ack != "Ack" {
		// Silent error to avoid spamming logs
		return nil, nil // errors.New("Not an Ack")
	}

	if ip, err = sharedutils.CleanIP(ip); err != nil {
		return nil, errors.New("Invalid IP")
	}

	if err := s.NotRateLimited(mac + ":" + ip); err != nil {
		return nil, err
	}
	apiCall := []ApiCall{
		&PfqueueApiCall{
			Method: "update_ip4log",
			Params: []interface{}{
				"mac", mac,
				"ip", ip,
				"lease_length", lease,
			},
		},
	}
	if hostname != "N/A" && hostname != "" {
		apiCall = append(apiCall, &PfqueueApiCall{
			Method: "modify_node",
			Params: []interface{}{
				"mac", mac,
				"computername", hostname,
			},
		})
	}
	return apiCall, nil
}

func NewFortiGateDhcpParser(config *PfdetectConfig) (Parser, error) {
	return &FortiGateDhcpParser{
		Pattern1: fortiGateDhcpRegexPattern1,
		parser:   setupParser(config),
	}, nil
}
