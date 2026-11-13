package util

import (
	"strconv"
	"strings"
)

// LengthPrefixedKey joins parts into one key, writing each part as its byte
// length, a colon and the part itself ("2:ab0:1:c" for "ab", "", "c").
// Different lists of parts always give different keys, whatever bytes the
// parts contain, unlike joining them with a separator.
func LengthPrefixedKey(parts ...string) string {
	var b strings.Builder
	for _, p := range parts {
		b.WriteString(strconv.Itoa(len(p)))
		b.WriteByte(':')
		b.WriteString(p)
	}
	return b.String()
}
