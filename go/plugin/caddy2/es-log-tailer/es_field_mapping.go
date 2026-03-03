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
// Handles these formats:
//   - Go:         t=... lvl=info msg="..."
//   - PF httpd:   httpd.portal(120) WARN: ..., httpd.aaa(7) INFO: ...
//   - Perl -e:    -e(pid) LEVEL: ...
//   - FreeRADIUS: Sun Mar  1 02:02:19 2026 : Error: ...
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

	// PF httpd / Perl format: <name>(<digits>) <LEVEL>: <message>
	// Matches: httpd.portal(120) WARN:, httpd.aaa(7) INFO:, -e(pid) ERROR:
	if parenOpen := strings.IndexByte(message, '('); parenOpen >= 0 && parenOpen < 40 {
		parenClose := strings.IndexByte(message[parenOpen+1:], ')')
		if parenClose > 0 {
			digits := message[parenOpen+1 : parenOpen+1+parenClose]
			allDigits := true
			for _, c := range digits {
				if c < '0' || c > '9' {
					allDigits = false
					break
				}
			}
			absClose := parenOpen + 1 + parenClose
			if allDigits && absClose+2 < len(message) && message[absClose+1] == ' ' {
				rest := message[absClose+2:]
				colonIdx := strings.IndexByte(rest, ':')
				if colonIdx > 0 && colonIdx <= 10 {
					level := rest[:colonIdx]
					valid := len(level) > 0
					for _, c := range level {
						if c < 'A' || c > 'Z' {
							valid = false
							break
						}
					}
					if valid {
						return strings.ToLower(level)
					}
				}
			}
		}
	}

	// FreeRADIUS format: <Day Mon DD HH:MM:SS YYYY> : <Level>: <message>
	// The " : " separator appears after the timestamp, followed by a title-case level word.
	if idx := strings.Index(message, " : "); idx >= 0 && idx < 40 {
		rest := message[idx+3:]
		colonIdx := strings.IndexByte(rest, ':')
		if colonIdx >= 3 && colonIdx <= 10 {
			candidate := rest[:colonIdx]
			if candidate[0] >= 'A' && candidate[0] <= 'Z' {
				allAlpha := true
				for _, c := range candidate {
					if (c < 'a' || c > 'z') && (c < 'A' || c > 'Z') {
						allAlpha = false
						break
					}
				}
				if allAlpha {
					return strings.ToLower(candidate)
				}
			}
		}
	}

	// Plain prefix: messages starting with a known level keyword followed by a
	// non-letter (e.g. "error reading from socket", "error from client at ...").
	lower := strings.ToLower(message)
	for _, prefix := range []string{"error", "warning", "warn", "info", "debug"} {
		if strings.HasPrefix(lower, prefix) && (len(message) == len(prefix) || message[len(prefix)] < 'a' || message[len(prefix)] > 'z') {
			if prefix == "warning" {
				return "warn"
			}
			return prefix
		}
	}

	// Default: every log line is at least informational.  Returning "" would
	// create a blank entry in the frontend's log-level scope filter.
	return "info"
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
