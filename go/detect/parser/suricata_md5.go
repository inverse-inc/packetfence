package parser

import (
	"encoding/json"
	"fmt"
	"regexp"
)

var suricataMD5RegexPattern1 = regexp.MustCompile(`^[^\{]*`)

type SuricataMD5Parser struct {
	Pattern1 *regexp.Regexp
}

func (s *SuricataMD5Parser) Parse(line string) ([]ApiCall, error) {
	var data map[string]interface{}
	jsonString := s.Pattern1.ReplaceAllString(line, "")
	fmt.Println(jsonString)
	if err := json.Unmarshal([]byte(jsonString), &data); err != nil {
		return nil, err
	}

	if _, found := data["md5"]; !found {
		return nil, nil
	}

	var endpointKey string
	if tmp, found := data["http_host"]; found {
		if str, ok := tmp.(string); ok && str != "" {
			endpointKey = "dstip"
		}
	} else if tmp, found := data["sender"]; found {
		if str, ok := tmp.(string); ok && str != "" {
			endpointKey = "srcip"
		}
	}

	if _, found := data[endpointKey]; !found {
		return nil, nil
	}

	return []ApiCall{
		&JsonRpcApiCall{
			Method: "metadefender_process",
			Params: data,
		}}, nil

	return nil, fmt.Errorf("Parse Error")
}

func NewSuricataMD5Parser(interface{}) Parser {
	return &SuricataMD5Parser{
		Pattern1: suricataMD5RegexPattern1.Copy(),
	}
}
