package parser

import (
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"
)

type GenericParser struct {
	Pattern *regexp.Regexp
	Rules   []GenericParserRule
}

var genericPatternRegex = regexp.MustCompile(`\s*[,=]\s*`)

type GenericParserAction struct {
	MethodName, ArgsTemplate string
}

type GenericParserRule struct {
	Match       *regexp.Regexp
	Name        string
	LastIfMatch bool
	Actions     []GenericParserAction
}

var macGarbageRegex = regexp.MustCompile(`[\s\-\.:]`)
var validSimpleMacHexRegex = regexp.MustCompile(`^[a-fA-F0-9]{12}$`)
var macPairHexRegex = regexp.MustCompile(`[a-fA-F0-9]{2}`)

func cleanMac(mac string) string {
	mac = macGarbageRegex.ReplaceAllString(strings.ToLower(mac), "")
	if !macHexRegex.MatchString(mac) {
		return ""
	}

	return strings.TrimRight(
		macPairHexRegex.ReplaceAllStringFunc(
			mac,
			func(s string) string { return s + ":" },
		),
		":",
	)
}

func stringExpander(name string, num int, value string) string {
	if name == "mac" {
		return cleanMac(value)
	}
	return value
}

func (s *GenericParser) Parse(line string) ([]ApiCall, error) {
	var calls []ApiCall
	var results []byte
	for _, rule := range s.Rules {
		submatches := rule.Match.FindStringSubmatchIndex(line)
		if submatches == nil {
			continue
		}

		for _, action := range rule.Actions {
			results = results[:0]
			results = rule.ExpandStringFunc(results, action.ArgsTemplate, line, submatches, stringExpander)
			calls = append(
				calls,
				&JsonRpcApiCall{
					Method: action.MethodName,
					Params: s.Pattern.Split(string(results), -1),
				},
			)
		}

		if rule.LastIfMatch {
			break
		}
	}

	return calls, nil
}

// extract returns the name from a leading "$name" or "${name}" in str.
// If it is a number, extract returns num set to that number; otherwise num = -1.
func extract(str string) (name string, num int, rest string, ok bool) {
	if len(str) < 2 || str[0] != '$' {
		return
	}
	brace := false
	if str[1] == '{' {
		brace = true
		str = str[2:]
	} else {
		str = str[1:]
	}
	i := 0
	for i < len(str) {
		rune, size := utf8.DecodeRuneInString(str[i:])
		if !unicode.IsLetter(rune) && !unicode.IsDigit(rune) && rune != '_' {
			break
		}
		i += size
	}
	if i == 0 {
		// empty name is not okay
		return
	}
	name = str[:i]
	if brace {
		if i >= len(str) || str[i] != '}' {
			// missing closing brace
			return
		}
		i++
	}

	// Parse number.
	num = 0
	for i := 0; i < len(name); i++ {
		if name[i] < '0' || '9' < name[i] || num >= 1e8 {
			num = -1
			break
		}
		num = num*10 + int(name[i]) - '0'
	}
	// Disallow leading zeros.
	if name[0] == '0' && len(name) > 1 {
		num = -1
	}

	rest = str[i:]
	ok = true
	return
}

func genericStringExpander(name string, num int, value string) string {
	return value
}

func (rule *GenericParserRule) ExpandString(dst []byte, template string, src string, match []int) []byte {
	return rule.ExpandStringFunc(dst, template, src, match, genericStringExpander)
}

func (rule *GenericParserRule) ExpandStringFunc(dst []byte, template string, src string, match []int, replacements func(name string, num int, value string) string) []byte {
	subexpNames := rule.Match.SubexpNames()
	for len(template) > 0 {
		i := strings.Index(template, "$")
		if i < 0 {
			break
		}
		dst = append(dst, template[:i]...)
		template = template[i:]
		if len(template) > 1 && template[1] == '$' {
			// Treat $$ as $.
			dst = append(dst, '$')
			template = template[2:]
			continue
		}
		name, num, rest, ok := extract(template)
		if !ok {
			// Malformed; treat $ as raw text.
			dst = append(dst, '$')
			template = template[1:]
			continue
		}
		template = rest
		var replace_string string
		if num >= 0 {
			if 2*num+1 < len(match) && match[2*num] >= 0 {
				replace_string = src[match[2*num]:match[2*num+1]]
			}
		} else {
			for i, namei := range subexpNames {
				if name == namei && 2*i+1 < len(match) && match[2*i] >= 0 {
					replace_string = src[match[2*i]:match[2*i+1]]
					break
				}
			}
		}
		replace_string = replacements(name, num, replace_string)

		dst = append(dst, replace_string...)
	}
	return append(dst, template...)
}

func NewGenericParser(interface{}) (Parser, error) {
	return &GenericParser{
		Pattern: genericPatternRegex.Copy(),
	}, nil
}
