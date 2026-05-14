package cloud

import (
	"context"
	"crypto/x509"
	"fmt"
)

type Cloud interface {
	NewCloud(ctx context.Context, name string) error
	ValidateRequest(ctx context.Context, data []byte) error
	SuccessReply(ctx context.Context, cert *x509.Certificate, data []byte, message string) error
	FailureReply(ctx context.Context, cert *x509.Certificate, data []byte, message string) error
}

// RevocationRequest carries one pending revocation that the cloud
// provider has handed back to us. SerialNumber is the canonical key
// against pki_certs/pki_revoked_certs; Thumbprint is a verification
// hint when present (Intune supplies it).
type RevocationRequest struct {
	RequestID    string
	SerialNumber string
	Thumbprint   string
	Reason       int
	IssuerName   string
}

// RevocationResult is the per-request outcome the caller hands back to
// the cloud provider, so it can stop re-sending the same item.
type RevocationResult struct {
	RequestID        string
	Succeeded        bool
	ErrorDescription string
}

// RevokeFunc is supplied by the caller (pfpki) and is called once per
// downloaded revocation. Implementations should be idempotent — Intune
// may re-send a request until it gets a positive acknowledgement.
type RevokeFunc func(ctx context.Context, req RevocationRequest) RevocationResult

// RevocationProcessor is an *optional* capability for Cloud providers
// that publish a revocation feed (Intune is the only one today). Callers
// check for it via type assertion; absence means "this provider doesn't
// expose revocations and there's nothing to drain".
type RevocationProcessor interface {
	// ProcessRevocations downloads pending revocation requests for the
	// named CA (the issuer's Common Name), invokes revoke for each, and
	// acknowledges the per-request outcome back to the provider.
	// Returns the number of requests processed (regardless of outcome).
	ProcessRevocations(ctx context.Context, caName string, revoke RevokeFunc) (int, error)
}

// Creater function
type Creater func(context.Context, string) (Cloud, error)

var cloudLookup = map[string]Creater{
	"intune": NewIntuneCloud,
}

// Create function
func Create(ctx context.Context, cloudType string, name string) (Cloud, error) {
	if creater, found := cloudLookup[cloudType]; found {
		return creater(ctx, name)
	}

	return nil, fmt.Errorf("Cloud of %s not found", cloudType)
}
