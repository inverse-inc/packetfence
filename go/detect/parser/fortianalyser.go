package parser

import (
	"fmt"
	"regexp"
)

var fortiAnalyserRegexPattern1 = regexp.MustCompile(`\s+`)
var fortiAnalyserRegexPattern2 = regexp.MustCompile(`\=`)

type FortiAnalyserParser struct {
	Pattern1, Pattern2 *regexp.Regexp
}

func (s *FortiAnalyserParser) Parse(line string) ([]ApiCall, error) {
	matches := s.Pattern1.Split(line, -1)
	var srcip, logid string
	for _, str := range matches {
		args := s.Pattern2.Split(str, 2)
		if len(args) <= 1 {
			continue
		}

		if args[0] == "srcip" {
			srcip = args[1]
		} else if args[0] == "logid" {
			logid = args[1]
		}
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

	return nil, fmt.Errorf("Error parsing")
}

func NewFortiAnalyserParser(*PfdetectConfig) (Parser, error) {
	return &FortiAnalyserParser{
		Pattern1: fortiAnalyserRegexPattern1.Copy(),
		Pattern2: fortiAnalyserRegexPattern2.Copy(),
	}, nil
}
