package main

import (
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyfile"
	"github.com/davecgh/go-spew/spew"
)

type ParserRuleAction struct {
	Method   string
	Template []string
}

type ParserRule struct {
	Name        string
	RegexStr    string
	Actions     []ParserRuleAction
	LastIfMatch bool
}

type ParserConfig struct {
	Type   string
	Path   string
	Id     string
	Status bool
	Rules  []ParserRule
}

type PFDetectContext struct {
	ParserConfigs map[string]*ParserConfig
}

func NewPFDetectContext() *PFDetectContext {
	return &PFDetectContext{ParserConfigs: make(map[string]*ParserConfig)}
}

func (c *PFDetectContext) InspectServerBlocks(content string, blocks []caddyfile.ServerBlock) ([]caddyfile.ServerBlock, error) {
	spew.Printf("block: %#v\n", blocks)
	return blocks, nil
}

func (c *PFDetectContext) MakeServers() ([]caddy.Server, error) {
	return []caddy.Server{}, nil
}

func (ctx *PFDetectContext) GetConfig(c *caddy.Controller) *ParserConfig {
	if config, found := ctx.ParserConfigs[c.Key]; found {
		return config
	}

	config := &ParserConfig{Id: c.Key}
	ctx.ParserConfigs[c.Key] = config
	return config
}
