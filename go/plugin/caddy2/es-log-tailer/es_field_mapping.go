package eslogtailer

import (
	"os"
	"strings"
	"time"
)

type ESFieldMapping struct {
	Timestamp        string
	Hostname         string
	LogLevel         string
	Process          string
	SyslogName       string
	LogWithoutPrefix string
	Filename         string
	RawMessage       string
}

type LogMeta struct {
	Timestamp        time.Time `json:"timestamp"`
	Hostname         string    `json:"hostname"`
	LogLevel         string    `json:"log_level"`
	Process          string    `json:"process"`
	SyslogName       string    `json:"syslog_name"`
	LogWithoutPrefix string    `json:"log_without_prefix"`
	Filename         string    `json:"filename"`
}

func envOrDefault(envVar, defaultVal string) string {
	if v := os.Getenv(envVar); v != "" {
		return v
	}
	return defaultVal
}

func NewESFieldMappingFromEnv() *ESFieldMapping {
	return &ESFieldMapping{
		Timestamp:        envOrDefault("ES_FIELD_TIMESTAMP", "@timestamp"),
		Hostname:         envOrDefault("ES_FIELD_HOSTNAME", "host.name"),
		LogLevel:         envOrDefault("ES_FIELD_LOG_LEVEL", "log.level"),
		Process:          envOrDefault("ES_FIELD_PROCESS", "process.name"),
		SyslogName:       envOrDefault("ES_FIELD_SYSLOG_NAME", "log.syslog.identifier"),
		LogWithoutPrefix: envOrDefault("ES_FIELD_MESSAGE", "message"),
		Filename:         envOrDefault("ES_FIELD_FILENAME", "log.file.path"),
		RawMessage:       envOrDefault("ES_FIELD_RAW", "message"),
	}
}

func (fm *ESFieldMapping) ExtractLogMeta(source map[string]interface{}) LogMeta {
	var lm LogMeta

	if ts := getNestedFieldString(source, fm.Timestamp); ts != "" {
		if t, err := time.Parse(time.RFC3339Nano, ts); err == nil {
			lm.Timestamp = t
		} else if t, err := time.Parse(time.RFC3339, ts); err == nil {
			lm.Timestamp = t
		}
	}

	lm.Hostname = getNestedFieldString(source, fm.Hostname)
	lm.LogLevel = getNestedFieldString(source, fm.LogLevel)
	lm.Process = getNestedFieldString(source, fm.Process)
	lm.SyslogName = getNestedFieldString(source, fm.SyslogName)
	lm.LogWithoutPrefix = getNestedFieldString(source, fm.LogWithoutPrefix)
	lm.Filename = getNestedFieldString(source, fm.Filename)

	return lm
}

func (fm *ESFieldMapping) GetRawMessage(source map[string]interface{}) string {
	return getNestedFieldString(source, fm.RawMessage)
}

func getNestedField(source map[string]interface{}, path string) interface{} {
	parts := strings.Split(path, ".")
	var current interface{} = source

	for _, part := range parts {
		m, ok := current.(map[string]interface{})
		if !ok {
			return nil
		}
		current, ok = m[part]
		if !ok {
			return nil
		}
	}

	return current
}

func getNestedFieldString(source map[string]interface{}, path string) string {
	val := getNestedField(source, path)
	if val == nil {
		return ""
	}
	if s, ok := val.(string); ok {
		return s
	}
	return ""
}
