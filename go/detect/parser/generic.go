package parser

import (
	"fmt"
	"regexp"
)

type GenericParser struct {
	Rules []GenericParserRule
}

type GenericParserAction struct {
	MethodName, ArgsTemplate string
}

type GenericParserRule struct {
	Match       *regexp.Regexp
	Name        string
	LastIfMatch bool
	Actions     []GenericParserAction
}

func (s *GenericParserRule) DoesMatch(line string) bool {

    return false;
}

func (s *GenericParser) Parse(line string) ([]ApiCall, error) {
    for _, rules := range s.Rules {
        _ = rules
    }
	return nil, fmt.Errorf("Error parsing")
}

func NewGenericParser(interface{}) (Parser, error) {
	return &GenericParser{
	}, nil
}
