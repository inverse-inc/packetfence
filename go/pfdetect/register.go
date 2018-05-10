package main

import (
	"fmt"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"io/ioutil"
	"os"
	"strings"
)

var DetectServerType = caddy.ServerType{
	Directives: func() []string { return []string{"type", "path", "status", "rule",} },
	NewContext: func() caddy.Context { return NewPFDetectContext() },
}

func init() {
	caddy.RegisterServerType("pfdetect", DetectServerType)
	caddy.SetDefaultCaddyfileLoader("default", caddy.LoaderFunc(defaultLoader))
	caddy.RegisterPlugin("type", caddy.Plugin{
		ServerType: "pfdetect",
		Action:     setupType,
	})
	caddy.RegisterPlugin("path", caddy.Plugin{
		ServerType: "pfdetect",
		Action:     setupPath,
	})
	caddy.RegisterPlugin("status", caddy.Plugin{
		ServerType: "pfdetect",
		Action:     setupStatus,
	})
	caddy.RegisterPlugin("rule", caddy.Plugin{
		ServerType: "pfdetect",
		Action:     setupRule,
	})
}

func setupRule(c *caddy.Controller) error {
	ctx := c.Context().(*PFDetectContext)
	config := ctx.GetConfig(c)
	rule := ParserRule{}
	for c.Next() {
		args := c.RemainingArgs()
		if len(args) != 1 {
			return c.ArgErr()
		}

		rule.Name = args[0]
		for c.NextBlock() {
			paramName := c.Val()
			switch paramName {
			default:
				return c.SyntaxErr(paramName)
			case "last_if_match":
				rule.LastIfMatch = true
			case "regex":
				if !c.NextArg() {
					return c.ArgErr()
				}
				rule.RegexStr = c.Val()
			case "action":
				if !c.NextArg() {
					return c.ArgErr()
				}
				rule.Actions = append(
					rule.Actions,
					ParserRuleAction{
						Method:   c.Val(),
						Template: c.RemainingArgs(),
					},
				)
			}
		}
	}

	config.Rules = append(config.Rules, rule)
	return nil
}

func setupType(c *caddy.Controller) error {
	c.Next() // pop type
	if !c.NextArg() {
		return fmt.Errorf("%s/%s: %s", "plugin", "type", c.ArgErr())
	}

	ctx := c.Context().(*PFDetectContext)
	config := ctx.GetConfig(c)
	config.Type = c.Val()

	return nil
}

func setupPath(c *caddy.Controller) error {
	c.Next() // pop type
	if !c.NextArg() {
		return fmt.Errorf("%s/%s: %s", "plugin", "path", c.ArgErr())
	}

	ctx := c.Context().(*PFDetectContext)
	config := ctx.GetConfig(c)
	config.Path = c.Val()

	return nil
}

var ISENABLED = map[string]bool{
	"enabled": true,
	"enable":  true,
	"yes":     true,
	"y":       true,
	"true":    true,
	"1":       true,

	"disabled": false,
	"disable":  false,
	"false":    false,
	"no":       false,
	"n":        false,
	"0":        false,
}

func IsEnabled(enabled string) bool {
	if e, found := ISENABLED[strings.TrimSpace(enabled)]; found {
		return e
	}

	return false
}

func setupStatus(c *caddy.Controller) error {
	c.Next() // pop type
	if !c.NextArg() {
		return fmt.Errorf("%s/%s: %s", "plugin", "status", c.ArgErr())
	}

	ctx := c.Context().(*PFDetectContext)
	config := ctx.GetConfig(c)
	status := c.Val()
	config.Status = IsEnabled(status)

	return nil
}

func defaultLoader(serverType string) (caddy.Input, error) {
	contents, err := ioutil.ReadFile(caddy.DefaultConfigFile)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}

		return nil, err
	}

	return caddy.CaddyfileInput{
		Contents:       contents,
		Filepath:       caddy.DefaultConfigFile,
		ServerTypeName: serverType,
	}, nil
}
