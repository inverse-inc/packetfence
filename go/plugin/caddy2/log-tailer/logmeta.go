package logtailer

import (
	"fmt"
	"regexp"
	"strings"
	"time"
)

const (
	logDebug = "debug"
	logInfo  = "info"
	logWarn  = "warn"
	logError = "error"
	logFatal = "fatal"
	logTrace = "trace"
)

type LogMetaEngine struct {
	SyslogMap           map[string]*LogMetaExtractor
	GlobalExtractionRe  *regexp.Regexp
	TimestampPos        int
	HostnamePos         int
	SyslogNamePos       int
	LogWithoutPrefixPos int
}

func reExtractor(re *regexp.Regexp, capturePosition int) func(string, string) string {
	return func(syslogName string, log string) string {
		if m := re.FindAllStringSubmatch(log, -1); m != nil {
			return m[0][capturePosition]
		} else {
			return ""
		}
	}
}

var logLevelImplicitDebug = func(string, string) string { return logDebug }
var logLevelImplicitInfo = func(string, string) string { return logInfo }
var logLevelImplicitWarn = func(string, string) string { return logWarn }
var logLevelImplicitError = func(string, string) string { return logError }

var errorRegexp = regexp.MustCompile(`(?i).*error.*`)
var freeradiusMetaExtractor = LogMetaExtractor{
	LogLevelExtractor: func(syslogName, log string) string {
		if errorRegexp.MatchString(log) {
			return logError
		} else {
			return logInfo
		}
	},
	ProcessNameExtractor: func(syslogName string, log string) string {
		return "radiusd"
	},
}

var golangMetaExtractor = LogMetaExtractor{
	LogLevelExtractor: reExtractor(regexp.MustCompile(`lvl=([a-z]+)`), 1),
	LogLevelNormalizer: func(level string) string {
		return map[string]string{
			"dbug": logDebug,
			"info": logInfo,
			"warn": logWarn,
			"eror": logError,
		}[level]
	},
	ProcessNameExtractor: func(syslogName, log string) string {
		return syslogName
	},
}

var log4perlMetaExtractor = LogMetaExtractor{
	LogLevelExtractor: reExtractor(regexp.MustCompile(`^(\S+\s+){6}([A-Z]+)`), 2),
	LogLevelNormalizer: func(level string) string {
		return strings.ToLower(level)
	},
	ProcessNameExtractor: reExtractor(regexp.MustCompile(`^(\S+\s+){5}(.+?)\(`), 2),
}

var apacheAccessMetaExtractor = LogMetaExtractor{
	LogLevelExtractor: logLevelImplicitInfo,
	ProcessNameExtractor: func(syslogName string, log string) string {
		return strings.Replace(syslogName, "_", ".", -1)
	},
}

var apacheErrorMetaExtractor = LogMetaExtractor{
	LogLevelExtractor: logLevelImplicitError,
	ProcessNameExtractor: func(syslogName string, log string) string {
		syslogName = strings.Replace(syslogName, "_", ".", -1)
		return strings.Replace(syslogName, ".err", "", -1)
	},
}

func NewRsyslogMetaEngine() *LogMetaEngine {
	return &LogMetaEngine{
		SyslogMap: map[string]*LogMetaExtractor{
			"acct":                          &freeradiusMetaExtractor,
			"api-frontend":                  &golangMetaExtractor,
			"auth":                          &freeradiusMetaExtractor,
			"fingerbank-collector":          &golangMetaExtractor,
			"httpd_aaa":                     &apacheAccessMetaExtractor,
			"httpd_aaa_err":                 &apacheErrorMetaExtractor,
			"httpd_admin_access":            &apacheAccessMetaExtractor,
			"httpd_admin_err":               &apacheErrorMetaExtractor,
			"httpd_portal_access":           &apacheAccessMetaExtractor,
			"httpd_portal_err":              &apacheErrorMetaExtractor,
			"httpd_webservices_access":      &apacheAccessMetaExtractor,
			"httpd_webservices_err":         &apacheErrorMetaExtractor,
			"load_balancer":                 &freeradiusMetaExtractor,
			"packetfence":                   &log4perlMetaExtractor,
			"packetfence_httpd.aaa":         &log4perlMetaExtractor,
			"packetfence_httpd.portal":      &log4perlMetaExtractor,
			"packetfence_httpd.webservices": &log4perlMetaExtractor,
			"pfacct":                        &golangMetaExtractor,
			"pfdhcp":                        &golangMetaExtractor,
			"pfdhcplistener":                &log4perlMetaExtractor,
			"pfdns":                         &golangMetaExtractor,
			"pffilter":                      &log4perlMetaExtractor,
			"pfhttpd":                       &golangMetaExtractor,
			"pfipset":                       &golangMetaExtractor,
			"pfcron":                        &golangMetaExtractor,
			"pfqueue":                       &log4perlMetaExtractor,
			"pfsso":                         &golangMetaExtractor,
			"pfldapexplorer":                &golangMetaExtractor,
			"pfstats":                       &golangMetaExtractor,
		},
		GlobalExtractionRe:  regexp.MustCompile(`(?i)^([a-z]+\s*[0-9]{1,2}\s*[0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2})\s(.+?)\s(.+?)(:|\[\d+\]:)(.+)`),
		TimestampPos:        1,
		HostnamePos:         2,
		SyslogNamePos:       3,
		LogWithoutPrefixPos: 5,
	}
}

// The rsyslog file templates write an ISO-8601 (RFC3339) timestamp:
//
//	2026-06-11T00:00:18.164560+02:00 host pfperl-api-docker-wrapper[289102]: rest of line
//
// This is the format actually found in /usr/local/pf/logs today; the legacy
// "Jan _2 15:04:05" form below is kept as a fallback for older files. Both
// the live tailing sessions and the history endpoint parse lines through
// this engine, so the format contract exists exactly once.
var isoExtractionRe = regexp.MustCompile(`^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[+-]\d{2}:\d{2}|Z))\s+(\S+)\s+([^\[\s:]+)(?:\[\d+\])?:\s*(.*)$`)

// Level tokens as the PacketFence daemons emit them: log4perl/apache/syslog
// style level words in any casing and the golang lvl=<abbrev> form. Longer
// variants are listed before their prefixes so WARNING/CRITICAL match whole.
var isoLevelWordRe = regexp.MustCompile(`(?i)\b(DEBUG|INFO|NOTICE|WARNING|WARN|ERROR|ERR|CRITICAL|CRIT|FATAL|TRACE)\b`)
var isoLevelLvlRe = regexp.MustCompile(`\blvl=(dbug|info|warn|eror|crit)\b`)

// Keys are upper-case; look tokens up through strings.ToUpper so the word
// and lvl= forms share one normalization.
var isoLevelMap = map[string]string{
	"DEBUG": logDebug, "DBUG": logDebug, "TRACE": logTrace,
	"INFO": logInfo, "NOTICE": logInfo,
	"WARN": logWarn, "WARNING": logWarn,
	"ERROR": logError, "ERR": logError, "EROR": logError,
	"CRIT": logFatal, "CRITICAL": logFatal, "FATAL": logFatal,
}

// ExtractMetaISO parses an ISO-8601-prefixed syslog line. It returns the
// extracted meta, the raw timestamp string as it appears in the line, and
// whether the line carried a header at all (continuation lines of stack
// traces do not).
func (lme *LogMetaEngine) ExtractMetaISO(log string) (lm LogMeta, rawTs string, ok bool) {
	m := isoExtractionRe.FindStringSubmatch(log)
	if m == nil {
		return lm, "", false
	}
	rawTs = m[1]
	lm.Timestamp, _ = time.Parse(time.RFC3339Nano, rawTs)
	lm.Hostname = m[2]
	lm.SyslogName = m[3]
	lm.Process = m[3]
	lm.LogWithoutPrefix = strings.Trim(m[4], " ")

	// The structured lvl= token wins over prose level words: a debug line
	// whose message mentions "error" must stay debug.
	if lvl := isoLevelLvlRe.FindStringSubmatch(lm.LogWithoutPrefix); lvl != nil {
		lm.LogLevel = isoLevelMap[strings.ToUpper(lvl[1])]
	} else if lvl := isoLevelWordRe.FindStringSubmatch(lm.LogWithoutPrefix); lvl != nil {
		lm.LogLevel = isoLevelMap[strings.ToUpper(lvl[1])]
	}
	return lm, rawTs, true
}

func (lme *LogMetaEngine) ExtractMeta(log string) (lm LogMeta) {
	if isoMeta, _, ok := lme.ExtractMetaISO(log); ok {
		return isoMeta
	}

	if m := lme.GlobalExtractionRe.FindAllStringSubmatch(log, -1); m != nil {
		lm.Timestamp, _ = time.ParseInLocation("Jan _2 15:04:05 2006", fmt.Sprintf("%s %d", m[0][lme.TimestampPos], time.Now().Year()), time.Local)
		lm.Hostname = m[0][lme.HostnamePos]
		lm.SyslogName = m[0][lme.SyslogNamePos]
		lm.LogWithoutPrefix = strings.Trim(m[0][lme.LogWithoutPrefixPos], " ")
		if extractor := lme.SyslogMap[lm.SyslogName]; extractor != nil {
			extractor.ExtractMeta(lm.SyslogName, log, &lm)
		}
	}

	return lm
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

type LogMetaExtractor struct {
	LogLevelExtractor    func(string, string) string
	LogLevelNormalizer   func(string) string
	ProcessNameExtractor func(string, string) string
}

func (lme *LogMetaExtractor) ExtractMeta(syslogName, log string, lm *LogMeta) {
	if lme.LogLevelExtractor != nil {
		lm.LogLevel = lme.LogLevelExtractor(syslogName, log)
		if lme.LogLevelNormalizer != nil {
			lm.LogLevel = lme.LogLevelNormalizer(lm.LogLevel)
		}
	}

	if lme.ProcessNameExtractor != nil {
		lm.Process = lme.ProcessNameExtractor(syslogName, log)
	}
}
