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
		Timestamp:        envOrDefault("ES_FIELD_TIMESTAMP", "timestamp"),
		Hostname:         envOrDefault("ES_FIELD_HOSTNAME", "kubernetes.host"),
		LogLevel:         envOrDefault("ES_FIELD_LOG_LEVEL", ""),
		Process:          envOrDefault("ES_FIELD_PROCESS", "kubernetes.container_name"),
		SyslogName:       envOrDefault("ES_FIELD_SYSLOG_NAME", "kubernetes.container_name"),
		LogWithoutPrefix: envOrDefault("ES_FIELD_MESSAGE", "message"),
		Filename:         envOrDefault("ES_FIELD_FILENAME", ""),
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
	if lm.Filename == "" && lm.SyslogName != "" {
		lm.Filename = lm.SyslogName
	}

	// Fallback: extract log level from the raw message when the field is empty
	if lm.LogLevel == "" {
		raw := getNestedFieldString(source, fm.RawMessage)
		lm.LogLevel = extractLogLevelFromMessage(raw)
	}

	return lm
}

// extractLogLevelFromMessage parses the log level from the raw message body.
// Handles Go log format (lvl=info/warn/eror/dbug/trce) and
// Perl log format (-e(pid) LEVEL: ...).
func extractLogLevelFromMessage(message string) string {
	// Go log format: lvl=info, lvl=warn, lvl=eror, lvl=dbug, lvl=trce
	idx := strings.Index(message, "lvl=")
	if idx >= 0 {
		rest := message[idx+4:]
		end := strings.IndexByte(rest, ' ')
		if end < 0 {
			end = len(rest)
		}
		lvl := rest[:end]
		switch lvl {
		case "info":
			return "info"
		case "warn":
			return "warn"
		case "eror":
			return "error"
		case "dbug":
			return "debug"
		case "trce":
			return "trace"
		default:
			return strings.ToLower(lvl)
		}
	}

	// Perl log format: -e(pid) LEVEL: message
	if strings.HasPrefix(message, "-e(") {
		parenEnd := strings.IndexByte(message, ')')
		if parenEnd > 0 && parenEnd+2 < len(message) {
			rest := message[parenEnd+2:]
			colonIdx := strings.IndexByte(rest, ':')
			if colonIdx > 0 {
				level := rest[:colonIdx]
				valid := true
				for _, c := range level {
					if c < 'A' || c > 'Z' {
						valid = false
						break
					}
				}
				if valid && len(level) <= 10 {
					return strings.ToLower(level)
				}
			}
		}
	}

	return ""
}

func (fm *ESFieldMapping) GetRawMessage(source map[string]interface{}) string {
	return getNestedFieldString(source, fm.RawMessage)
}

func getNestedField(source map[string]interface{}, path string) interface{} {
	if path == "" {
		return nil
	}
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
