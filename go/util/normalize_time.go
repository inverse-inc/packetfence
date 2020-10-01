package util

import (
	"errors"
	"regexp"
	"strconv"
	"time"
)

var normalizeTimeRe = regexp.MustCompile(`(\d+)([smhDWMY]*)`)

func NormalizeTime(spec string) (time.Duration, error) {
	matches := normalizeTimeRe.FindStringSubmatch(spec)
	if len(matches) == 0 {
		return 0, errors.New(spec + " is not valid")
	}

	i, err := strconv.ParseInt(matches[1], 10, 64)
	if err != nil {
		return 0, err
	}

	switch matches[2] {
	default:
		return 0, err
	case "s", "":
		return time.Duration(i) * time.Second, nil
	case "m":
		return time.Duration(i) * time.Minute, nil
	case "h":
		return time.Duration(i) * time.Hour, nil
	case "D":
		return time.Duration(i) * time.Hour * 24, nil
	case "W":
		return time.Duration(i) * time.Hour * 24 * 7, nil
	case "M":
		return time.Duration(i) * time.Hour * 24 * 30, nil
	case "Y":
		return time.Duration(i) * time.Hour * 24 * 365, nil
	}
	return 0, err
}
