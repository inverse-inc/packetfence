package manager

import (
	"context"
	"log/slog"

	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/loader"
)

func dispatchMethod(ctx context.Context, logger *slog.Logger, conf *loader.Conf, request Request) (any, error) {
	return nil, nil
}
