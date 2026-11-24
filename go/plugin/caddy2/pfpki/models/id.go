package models

import (
	"errors"
	"strconv"
)

// ErrInvalidID is returned when an {id} URL parameter is not a number.
var ErrInvalidID = errors.New("invalid id")

// parseID parses an {id} URL parameter. The id must be parsed before it
// reaches gorm: an inline condition such as First(&x, id) or
// Delete(&X{}, id) uses a non-numeric string as a raw WHERE clause, so a
// string id from the URL would end up in the SQL.
func parseID(val string) (uint, error) {
	id, err := strconv.ParseUint(val, 10, strconv.IntSize)
	if err != nil {
		return 0, ErrInvalidID
	}
	return uint(id), nil
}
