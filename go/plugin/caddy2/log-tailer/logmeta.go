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

func (lme *LogMetaEngine) ExtractMeta(log string) (lm LogMeta) {
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
