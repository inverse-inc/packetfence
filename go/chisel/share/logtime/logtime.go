// Package logtime reads the timestamp at the start of a log line of the
// connector-remote (pfconnector-client, FreeRADIUS, keepalived, the
// collector, the upgrade/install logs) and the lines of a log written since
// a given time.
package logtime

import (
	"bufio"
	"os"
	"strings"
	"time"
)

// The timestamp layouts at the start of the lines, in the local time of the
// connector (its container TZ).
var layouts = []struct {
	prefix string // literal before the timestamp
	layout string
}{
	{"", "2006/01/02 15:04:05"},         // Go log: pfconnector-client, connector-cache
	{"", "Mon Jan _2 15:04:05 2006"},    // FreeRADIUS, keepalived
	{"[GIN] ", "2006/01/02 - 15:04:05"}, // fingerbank-collector
	{"[", "2006-01-02 15:04:05"},        // upgrade.log, install.log
}

// Parse returns the time a log line starts with, in loc.
func Parse(line string, loc *time.Location) (time.Time, bool) {
	for _, l := range layouts {
		if !strings.HasPrefix(line, l.prefix) {
			continue
		}
		rest := line[len(l.prefix):]
		if len(rest) < len(l.layout) {
			continue
		}
		if t, err := time.ParseInLocation(l.layout, rest[:len(l.layout)], loc); err == nil {
			return t, true
		}
	}
	return time.Time{}, false
}

// maxLineSize bounds a single log line read by LinesSince.
const maxLineSize = 1024 * 1024

// LinesSince returns up to max lines of fileName, starting at the first line
// stamped at or after since. Lines without a timestamp (continuations) belong
// to the line before. found is false when no line is that recent.
func LinesSince(fileName string, since time.Time, max int, loc *time.Location) (lines []string, found bool, err error) {
	f, err := os.Open(fileName)
	if err != nil {
		return nil, false, err
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 64*1024), maxLineSize)
	for scanner.Scan() {
		line := scanner.Text()
		if !found {
			t, ok := Parse(line, loc)
			if !ok || t.Before(since) {
				continue
			}
			found = true
		}
		lines = append(lines, line)
		if len(lines) >= max {
			break
		}
	}
	return lines, found, scanner.Err()
}
