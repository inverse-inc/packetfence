package detectparser

import (
	"regexp"

	"github.com/inverse-inc/go-utils/sharedutils"
)

var fortiAnalyserRegexPattern1 = regexp.MustCompile(`(\w+)="([^"]*)"|(\w+)=([^\s]+)`)

type FortiAnalyserParser struct {
	Pattern1 *regexp.Regexp
	parser
}

func (s *FortiAnalyserParser) Parse(line string) ([]ApiCall, error) {
	matches := s.Pattern1.FindAllStringSubmatch(line, -1)
	var srcip, logid string
	var err error

	attributes := make(map[string]string)

	for _, match := range matches {
		if match[1] != "" {
			attributes[match[1]] = match[2]
		} else {
			attributes[match[3]] = match[4]
		}
	}

	if value, ok := attributes["srcip"]; ok {
		srcip = value
	}
	if value, ok := attributes["logid"]; ok {
		logid = value
	}

	if srcip == "" || logid == "" {
		return nil, nil
	}

	if srcip, err = sharedutils.CleanIP(srcip); err != nil {
		return nil, nil
	}

	if err := s.NotRateLimited(srcip + ":" + logid); err != nil {
		return nil, err
	}

	return []ApiCall{
		&PfqueueApiCall{
			Method: "event_add",
			Params: []interface{}{
				"srcip", srcip,
				"events", map[string]interface{}{
					"detect": logid,
				},
			},
		},
	}, nil
}

func NewFortiAnalyserParser(config *PfdetectConfig) (Parser, error) {
	return &FortiAnalyserParser{
		Pattern1: fortiAnalyserRegexPattern1,
		parser:   setupParser(config),
	}, nil
}
