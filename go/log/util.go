package log

import (
	"context"
	"fmt"
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

func LogErrorf(ctx context.Context, msg string, args ...interface{}) {
	LoggerWContext(ctx).Error(fmt.Sprintf(msg, args...))
}

func LogWarnf(ctx context.Context, msg string, args ...interface{}) {
	LoggerWContext(ctx).Warn(fmt.Sprintf(msg, args...))
}

func LogInfof(ctx context.Context, msg string, args ...interface{}) {
	LoggerWContext(ctx).Info(fmt.Sprintf(msg, args...))
}

func LogDebugf(ctx context.Context, msg string, args ...interface{}) {
	LoggerWContext(ctx).Debug(fmt.Sprintf(msg, args...))
}
