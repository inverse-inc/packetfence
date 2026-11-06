package utils

import (
	"reflect"
	"unsafe"
)

var trueFalseValues = map[string]bool{
	"enabled":  true,
	"enable":   true,
	"yes":      true,
	"y":        true,
	"Y":        true,
	"true":     true,
	"1":        true,
	"disabled": false,
	"disable":  false,
	"false":    false,
	"no":       false,
	"n":        false,
	"N":        false,
	"0":        false,
	"":         false,
}

func StringToBytes(s string) []byte {
	return unsafe.Slice(unsafe.StringData(s), len(s))
}

func IsEnabled(s string) bool {
	if v, ok := trueFalseValues[s]; ok {
		return v
	}
	return false
}

// NewValueFromType Creates a zero value for generic type T:
// For pointer types, returns a pointer to a new instance of the underlying type;
// For non-pointer types, returns the zero value;
func NewValueFromType[T any]() T {
	var x T
	t := reflect.TypeOf(x)
	if t != nil && t.Kind() == reflect.Pointer {
		elemType := t.Elem()
		return reflect.New(elemType).Interface().(T)
	}
	return x
}
