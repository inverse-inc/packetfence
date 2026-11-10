package models

import (
	"errors"
	"fmt"
)

// ErrInvalidSearch wraps the errors of a search query that can't be built (unknown field, operator...)
var ErrInvalidSearch = errors.New("invalid search")

func invalidSearch(err error) error {
	return fmt.Errorf("%w: %v", ErrInvalidSearch, err)
}

type Err struct {
	Message string `json:"message"`
}

type DBRes struct {
	Item       interface{} `json:"item,omitempty"`
	Items      interface{} `json:"items,omitempty"`
	Total      *int        `json:"total,omitempty"`
	NextCursor *int        `json:"nextCursor,omitempty"`
	PrevCursor *int        `json:"prevCursor,omitempty"`
}

// emptyPage is the result of a search without match: an empty list of items and a total of 0
func emptyPage[T any]() DBRes {
	total := 0
	return DBRes{Items: []T{}, Total: &total}
}

const dbError = "a database error occured. see logs for details"
