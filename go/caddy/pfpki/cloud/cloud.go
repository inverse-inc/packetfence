package cloud

import (
	"context"
	"fmt"
)

type Cloud interface {
	NewCloud(ctx context.Context, name string)
	ValidateRequest(ctx context.Context, data []byte)
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
