package main

import (
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyfile"
)

type ParserConfig struct {
	Type   string
	Path   string
	Id     string
	Status bool
}

type PFDetectContext struct {
	ParserConfigs map[string]*ParserConfig
}

func NewPFDetectContext() *PFDetectContext {
	return &PFDetectContext{ParserConfigs: make(map[string]*ParserConfig)}
}

func (c *PFDetectContext) InspectServerBlocks(content string, blocks []caddyfile.ServerBlock) ([]caddyfile.ServerBlock, error) {
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
