package db

import (
	"errors"
	"strings"
)

var scanError = errors.New("Invalid type given")

type CsvArray []string

func (a *CsvArray) Scan(src interface{}) error {
	if src == nil {
		*a = nil
		return nil
	}

	var tmp string
	switch s := src.(type) {
	case *string:
		tmp = *s
	case []byte:
		tmp = string(s)
	default:
		return scanError
	}

	*a = strings.Split(tmp, ",")
	return nil
}

func (a *CsvArray) Value() (interface{}, error) {
	return strings.Join(*a, ","), nil
}
