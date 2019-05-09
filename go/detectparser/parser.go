package detectparser

import (
	"context"
	"fmt"
	cache "github.com/fdurand/go-cache"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/pfqueueclient"
	"time"
)

type PfdetectRegexRule struct {
	Actions           []string `json:"actions"`
	IpMacTranslation  string   `json:"ip_mac_translation"`
	LastIfMatch       string   `json:"last_if_match"`
	Name              string   `json:"name"`
	Regex             string   `json:"regex"`
	RateLimit         int      `json:"rate_limit"`
	RateLimitTemplate string   `json:"rate_limit_template"`
}

type PfdetectConfig struct {
	pfconfigdriver.StructConfig
	pfconfigdriver.TypedConfig
	PfconfigMethod string              `val:"hash_element"`
	PfconfigNS     string              `val:"config::Pfdetect"`
	PfconfigHashNS string              `val:"-"`
	Name           string              `json:"name,omitempty"`
	Path           string              `json:"path"`
	Status         string              `json:"status"`
	RateLimit      int                 `json:"rate_limit"`
	Rules          []PfdetectRegexRule `json:"rules"`
}

func (config *PfdetectConfig) NewRateLimitable() RateLimitable {
	if config == nil {
		return RateLimitable{}
	}

	return NewRateLimitable(config.RateLimit)
}

type RateLimitable struct {
	RateLimitCache *cache.Cache
}

func NewRateLimitable(rateLimit int) RateLimitable {
	var Cache *cache.Cache = nil
	if rateLimit != 0 {
		Cache = cache.New(time.Duration(rateLimit)*time.Second, 2*time.Duration(rateLimit)*time.Second)
	}

	return RateLimitable{RateLimitCache: Cache}
}

var errorRateLimit = fmt.Errorf("Already processed")

func (r RateLimitable) NotRateLimited(key string) error {
	if r.RateLimitCache == nil {
		return nil
	}
	if _, found := r.RateLimitCache.Get(key); found {
		return errorRateLimit
	}

	r.RateLimitCache.Set(key, 1, cache.DefaultExpiration)
	return nil
}

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

type PfqueueApiCall struct {
	Method string
	Params interface{}
}

func (c *PfqueueApiCall) Call() error {
	args := []interface{}{c.Method}
	switch c.Params.(type) {
	case []interface{}:
		args = append(args, c.Params.([]interface{})...)
	case []string:
		for _, s := range c.Params.([]string) {
			args = append(args, s)
		}
	default:
		return fmt.Errorf("Invalid Parameters given")
	}

	pfqueueclient := pfqueueclient.NewPfQueueClient()
	_, err := pfqueueclient.Submit(context.Background(), "pfdetect", "api", args)
	if err != nil {
		return err
	}

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

type ParserCreater func(*PfdetectConfig) (Parser, error)

var parserLookup = map[string]ParserCreater{
	"dhcp":           NewDhcpParser,
	"fortianalyser":  NewFortiAnalyserParser,
	"regex":          NewGenericParser,
	"security_onion": NewSecurityOnionParser,
	"snort":          NewSnortParser,
	"suricata":       NewSnortParser,
	"nexpose":        NewNexposeParser,
	"suricata_md5":   NewSuricataMD5Parser,
}

func CreateParser(parserType string, parserConfig *PfdetectConfig) (Parser, error) {
	if creater, found := parserLookup[parserType]; found {
		return creater(parserConfig)
	}

	return nil, fmt.Errorf("Parser of %s not found", parserType)
}
