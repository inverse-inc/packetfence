package aaa

import (
	"strings"
)

var publicPaths = []string{
	apiPrefix + "/translations",
	apiPrefix + "/translation/",
}

func IsPathPublic(path string) bool {
	for _, s := range publicPaths {
		if strings.HasPrefix(path, s) {
			return true
		}
	}
	return false
}
