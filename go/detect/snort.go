package detect

import (
    "regexp"
)

var snortRegexPattern1 = regexp.MustCompile(`^(.*)\[\d+:(\d+):\d+\]\s+(.+?)\s+\[.+?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+){0,1}\s+\-\>\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+){0,1}`)

var snortRegexPattern2 = regexp.MustCompile(`^(.+?)\s+\[\*\*\]\s+\[\d+:(\d+):\d+\]\s+Portscan\s+detected\s+from\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})`)

type SnortParser struct{
    Pattern1, Pattern2 *regexp.Regexp
}

func (*SnortParser) Parse(line string) ([]ApiCall, error) {
    return nil, nil
}

func NewSnortParser() Parser {
    return &SnortParser{
        Pattern1 : snortRegexPattern1.Copy(),
        Pattern2 : snortRegexPattern2.Copy(),
    }
}
