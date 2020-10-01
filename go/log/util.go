package log

import (
	"context"
)

func LogError(ctx context.Context, msg string) {
	LoggerWContext(ctx).Error(msg)
}

func LogWarn(ctx context.Context, msg string) {
	LoggerWContext(ctx).Warn(msg)
}

func LogInfo(ctx context.Context, msg string) {
	LoggerWContext(ctx).Info(msg)
}

func LogDebug(ctx context.Context, msg string) {
	LoggerWContext(ctx).Debug(msg)
}
