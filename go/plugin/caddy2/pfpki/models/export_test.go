package models

import (
	"context"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/cloud"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
)

// SetCloudCreate replaces the cloud provider factory until the returned
// function is called.
func SetCloudCreate(f func(ctx context.Context, cloudType, name string) (cloud.Cloud, error)) (restore func()) {
	old := cloudCreate
	cloudCreate = f
	return func() { cloudCreate = old }
}

// SetRenewalMailer replaces the renewal mail sender until the returned
// function is called.
func SetRenewalMailer(f func(ctx context.Context, cert Cert, prof Profile) (types.Info, error)) (restore func()) {
	old := sendRenewalMail
	sendRenewalMail = f
	return func() { sendRenewalMail = old }
}
