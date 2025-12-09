package util

import (
	"errors"
	"reflect"
	"strconv"
)

// IsEmptyValue, check "omitempty" json tag
func IsEmptyValue(v *reflect.Value) bool {
	switch v.Kind() {
	case reflect.Array, reflect.Map, reflect.Slice, reflect.String:
		return v.Len() == 0
	case reflect.Bool,
		reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64,
		reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64, reflect.Uintptr,
		reflect.Float32, reflect.Float64,
		reflect.Interface, reflect.Pointer:
		return v.IsZero()
	default:
		return false
	}
}

// IsZeroValue, check "omitzero" json tag
func IsZeroValue(v *reflect.Value) bool {
	return v.IsZero()
}

// IsSliceOrArray
func IsSliceOrArray(value any) bool {
	switch reflect.TypeOf(value).Kind() {
	case reflect.Array, reflect.Slice:
		return true
	default:
		return false
	}
}

// HasLen, check if a value can be called with len()
func HasLen(value any) bool {
	switch reflect.TypeOf(value).Kind() {
	case reflect.Array, reflect.Chan, reflect.Map, reflect.Slice, reflect.String:
		return true
	default:
		return false
	}
}

// GetLen return the len by reflection of value. value MUST have been checked to implement Len
func GetLen(value any) int {
	return reflect.ValueOf(value).Len()
}

// FormatAnyToString convert any string, bool, int, uint and float to string
func FormatAnyToString(data any) (string, error) {
	switch reflect.TypeOf(data).Kind() {
	case reflect.String:
		return data.(string), nil
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return strconv.FormatInt(data.(int64), 10), nil
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return strconv.FormatUint(data.(uint64), 10), nil
	case reflect.Float32, reflect.Float64:
		return strconv.FormatFloat(data.(float64), 'f', 14, 64), nil
	case reflect.Bool:
		tmp := data.(bool)
		if tmp {
			return "1", nil
		} else {
			return "0", nil
		}
	default:
		return "", errors.New("Type not supported")
	}
}
