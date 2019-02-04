package detectparser

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"

	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

var suricataMD5RegexRemovePrefix = regexp.MustCompile(`^[^\{]*`)

type IPToMacResolver interface {
	IpToMac(string) (string, error)
}

type SuricataMD5Parser struct {
	RemovePrefix   *regexp.Regexp
	ResolverIp2Mac IPToMacResolver
}

func (s *SuricataMD5Parser) Parse(line string) ([]ApiCall, error) {
	var (
		ip, mac, tid string
		endpointKey  string
		ok, found    bool
		data         map[string]interface{}
		tmp          interface{}
		err          error
	)
	jsonString := s.RemovePrefix.ReplaceAllString(line, "")
	if err = json.Unmarshal([]byte(jsonString), &data); err != nil {
		return nil, err
	}

	if tmp, found = data["md5"]; !found {
		return nil, fmt.Errorf("md5 not found")
	}

	if tid, ok = tmp.(string); !ok {
		return nil, fmt.Errorf("md5 not found")
	}

	if tmp, found = data["http_host"]; found {
		if str, ok := tmp.(string); ok && str != "" {
			endpointKey = "dstip"
		}
	} else if tmp, found = data["sender"]; found {
		if str, ok := tmp.(string); ok && str != "" {
			endpointKey = "srcip"
		}
	}

	if tmp, found = data[endpointKey]; !found {
		return nil, fmt.Errorf("endpoint not found")
	}

	if ip, ok = tmp.(string); !ok {
		return nil, fmt.Errorf("endpoint not found")
	}

	if tmp, err = s.ResolverIp2Mac.IpToMac(ip); err != nil {
		return nil, err
	}

	if mac, ok = tmp.(string); !ok {
		return nil, fmt.Errorf("endpoint not found")
	}

	data["mac"] = mac
	return []ApiCall{
		&PfqueueApiCall{
			Method: "trigger_security_event",
			Params: []interface{}{
				"mac", mac,
				"tid", tid,
				"type", "suricata_md5",
			},
		},
	}, nil
}

func (*SuricataMD5Parser) IpToMac(ip string) (string, error) {
	var apiClient = unifiedapiclient.NewFromConfig(context.Background())
	foundMac := unifiedapiclient.Ip2MacResponse{}
	err := apiClient.Call(context.Background(), "GET", "/api/v1/ip4logs/ip2mac/"+ip, &foundMac)
	if err != nil {
		msg := fmt.Sprintf("Problem getting the mac for ip '%s': %s", ip, err)
		log.Logger().Error(msg)
		return "", fmt.Errorf("%s", msg)
	}

	return foundMac.Mac, nil
}

func NewSuricataMD5Parser(*PfdetectConfig) (Parser, error) {
	p := &SuricataMD5Parser{
		RemovePrefix: suricataMD5RegexRemovePrefix.Copy(),
	}
	p.ResolverIp2Mac = p
	return p, nil
}
