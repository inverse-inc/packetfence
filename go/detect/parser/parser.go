package parser

import (
	"fmt"
)

type Parser interface {
	Parse(string) ([]ApiCall, error)
}

type ApiCall interface {
	Call() error
}

type JsonRpcApiCall struct {
	Method string
	Params interface{}
}

func (*JsonRpcApiCall) Call() error {
	return nil
}

type RestApiCall struct {
	HttpMethod string
	Path       string
	Content    string
}

func (*RestApiCall) Call() error {
	return nil
}

type ParserCreater func(interface{}) (Parser, error)

var parserLookup = map[string]ParserCreater{

	"dhcp":           NewDhcpParser,
	"fortianalyser":  NewFortiAnalyserParser,
	"regex":          NewGenericParser,
	"security_onion": NewSecurityOnionParser,
	"snort":          NewSnortParser,
	"suricata":       NewSnortParser,
	"suricata_md5":   NewSuricataMD5Parser,
}

func CreateParser(parserType string, parserConfig interface{}) (Parser, error) {
	if creater, found := parserLookup[parserType]; found {
		return creater(parserConfig)
	}
	return nil, fmt.Errorf("Parser of %s not found", parserType)
}
