package models

import (
	"context"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
)

// SetRenewalMailer replaces the renewal mail sender until the returned
// function is called.
func SetRenewalMailer(f func(ctx context.Context, cert Cert, prof Profile) (types.Info, error)) (restore func()) {
	old := sendRenewalMail
	sendRenewalMail = f
	return func() { sendRenewalMail = old }
}
