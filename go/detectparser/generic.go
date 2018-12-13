package detectparser

import (
	"context"
	"fmt"
	"regexp"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	cache "github.com/fdurand/go-cache"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

type GenericParser struct {
	Pattern   *regexp.Regexp
	Rules     []GenericParserRule
	RateLimit *cache.Cache
}

var genericPatternRegex = regexp.MustCompile(`\s*[,=]\s*`)

type GenericParserAction struct {
	MethodName, ArgsTemplate string
}

type GenericParserRule struct {
	Match            *regexp.Regexp
	Name             string
	LastIfMatch      bool
	IpMacTranslation bool
	Actions          []GenericParserAction
}

func (s *GenericParser) Parse(line string) ([]ApiCall, error) {
	var calls []ApiCall
	var results []byte
	for _, rule := range s.Rules {
		submatches := rule.Match.FindStringSubmatchIndex(line)
		if submatches == nil {
			continue
		}

		replacements := rule.GetReplacementMap(context.Background(), line, submatches)
		if mac, found := replacements["mac"]; found {
			mac = sharedutils.CleanMac(mac)
			if mac == "" {
				continue
			}
			replacements["mac"] = mac
		}

		if ip, found := replacements["ip"]; found {
			if tmp, err := sharedutils.CleanIP(ip); err != nil {
				continue
			} else {
				replacements["ip"] = tmp
			}
		}

		for _, action := range rule.Actions {
			results = results[:0]
			results = rule.ExpandString(results, action.ArgsTemplate, line, submatches, replacements)
			calls = append(
				calls,
				&PfqueueApiCall{
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

func (rule *GenericParserRule) ExpandString(dst []byte, template string, src string, match []int, replacements map[string]string) []byte {
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
			if tmp, found := replacements[name]; found {
				replace_string = tmp
			}
		}

		dst = append(dst, replace_string...)
	}
	return append(dst, template...)
}

func (rule *GenericParserRule) GetReplacementMap(ctx context.Context, src string, match []int) map[string]string {
	replacementStrings := make(map[string]string)
	subexpNames := rule.Match.SubexpNames()
	for i, name := range subexpNames {
		if name != "" {
			replacementStrings[name] = src[match[2*i]:match[2*i+1]]
		}
	}

	mac, macFound := replacementStrings["mac"]
	ip, ipFound := replacementStrings["ip"]
	if !rule.IpMacTranslation || (macFound == ipFound) {
		return replacementStrings
	}

	var apiClient = unifiedapiclient.NewFromConfig(ctx)
	if macFound {
		foundIp := unifiedapiclient.Mac2IpResponse{}
		err := apiClient.Call(ctx, "GET", "/api/v1/ip4logs/mac2ip/"+mac, &foundIp)
		if err != nil {
			log.Logger().Error(fmt.Sprintf("Problem getting the ip for mac '%s': %s", mac, err))
		} else {
			replacementStrings["ip"] = foundIp.Ip
		}
	} else {
		foundMac := unifiedapiclient.Ip2MacResponse{}
		err := apiClient.Call(ctx, "GET", "/api/v1/ip4logs/ip2mac/"+ip, &foundMac)
		if err != nil {
			log.Logger().Error(fmt.Sprintf("Problem getting the mac for ip '%s': %s", ip, err))
		} else {
			replacementStrings["mac"] = foundMac.Mac
		}
	}

	return replacementStrings
}

var splitActionRegex = regexp.MustCompile(`\s*:\s*`)

func MakeActions(array []string) []GenericParserAction {
	actions := []GenericParserAction{}
	for _, i := range array {
		args := splitActionRegex.Split(i, 2)
		actions = append(actions, GenericParserAction{MethodName: args[0], ArgsTemplate: args[1]})
	}
	return actions
}

func NewGenericParser(config *PfdetectConfig) (Parser, error) {
	rules := []GenericParserRule{}
	for _, rule := range config.Rules {
		rules = append(rules, GenericParserRule{
			Name:             rule.Name,
			LastIfMatch:      sharedutils.IsEnabled(rule.LastIfMatch),
			IpMacTranslation: sharedutils.IsEnabled(rule.IpMacTranslation),
			Match:            regexp.MustCompile(rule.Regex),
			Actions:          MakeActions(rule.Actions),
		},
		)
	}

	return &GenericParser{
		Pattern:   genericPatternRegex.Copy(),
		Rules:     rules,
		RateLimit: cache.New(5*time.Second, 10*time.Second),
	}, nil
}
