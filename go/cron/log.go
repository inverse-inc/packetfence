package maint

import (
	"context"
	"github.com/inverse-inc/packetfence/go/log"
)

func logError(ctx context.Context, msg string) {
	log.LoggerWContext(ctx).Error(msg)
}

func logWarn(ctx context.Context, msg string) {
	log.LoggerWContext(ctx).Warn(msg)
}

func logInfo(ctx context.Context, msg string) {
	log.LoggerWContext(ctx).Info(msg)
}

func logDebug(ctx context.Context, msg string) {
	log.LoggerWContext(ctx).Debug(msg)
}
