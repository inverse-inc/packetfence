package parser

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

type ParserCreater func(interface{}) (Parser)

var parserLookup = map[string]ParserCreater{

	"dhcp":          NewDhcpParser,
	"fortianalyser": NewFortiAnalyserParser,
	//"regex" : NewRegexParser,
	"security_onion": NewSecurityOnionParser,
	"snort":          NewSnortParser,
	"suricata_md5":   NewSuricataMD5Parser,
	"suricata":       NewSnortParser,
}

func CreateParser(parserType string, parserConfig interface{}) (Parser, error) {
	return nil, nil
}
