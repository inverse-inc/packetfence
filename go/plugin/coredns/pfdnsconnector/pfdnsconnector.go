// Package pfdns implements a plugin that returns details about the resolving
// querying it.
package pfdnsconnector

import (
	"context"

	"github.com/coredns/coredns/plugin"
	"github.com/miekg/dns"

	//Import mysql driver
	_ "github.com/go-sql-driver/mysql"
)

type pfdnsconnector struct {
	Next plugin.Handler
}

// Name implements the Handler interface.
func (pf *pfdnsconnector) Name() string { return "pfdnsconnector" }

// ServeDNS implements the middleware.Handler interface.
func (pf *pfdnsconnector) ServeDNS(ctx context.Context, w dns.ResponseWriter, r *dns.Msg) (int, error) {
	return pf.Next.ServeDNS(ctx, w, r)
}
