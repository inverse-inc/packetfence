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
