package sharedutils

import (
	"errors"
	"fmt"
	"github.com/cevaris/ordered_map"
	"github.com/kr/pretty"
	"os"
	"strconv"
	"strings"
	"testing"
	"unicode"
)

func UcFirst(str string) string {
	for i, v := range str {
		return string(unicode.ToUpper(v)) + str[i+1:]
	}
	return ""
}

func LcFirst(str string) string {
	for i, v := range str {
		return string(unicode.ToLower(v)) + str[i+1:]
	}
	return ""
}

// TODO: handle odd number of elements in args
func TupleToOrderedMap(args []interface{}) (*ordered_map.OrderedMap, error) {
	if len(args)%2 != 0 {
		return nil, errors.New("Odd number of elements in args for TupleToOrderedMap")
	}
	m := ordered_map.NewOrderedMap()
	var key interface{}
	for i, o := range args {
		if i%2 == 1 {
			m.Set(key, o)
		} else {
			key = o
		}
	}
	return m, nil
}

func CopyOrderedMap(m *ordered_map.OrderedMap) *ordered_map.OrderedMap {
	newMap := ordered_map.NewOrderedMap()

	iter := m.IterFunc()
	for kv, ok := iter(); ok; kv, ok = iter() {
		newMap.Set(kv.Key, kv.Value)
	}
	return newMap
}

// TODO: handle odd number of elements in args
func TupleToMap(args []interface{}) (map[interface{}]interface{}, error) {
	if len(args)%2 != 0 {
		return nil, errors.New("Odd number of elements in args for TupleToMap")
	}
	m := make(map[interface{}]interface{})
	var key interface{}
	for i, o := range args {
		if i%2 == 1 {
			m[key] = o
		} else {
			key = o
		}
	}
	return m, nil
}

func CopyMap(m map[interface{}]interface{}) map[interface{}]interface{} {
	newMap := make(map[interface{}]interface{})
	for k, v := range m {
		newMap[k] = v
	}
	return newMap
}

func CheckError(err error) {
	if err != nil {
		panic(err)
	}
}

func CheckTestError(t *testing.T, err error) {
	if err != nil {
		t.Error(fmt.Sprintf("There was an error %s", err))
	}
}

func SprintDump(args ...interface{}) string {
	return CleanForLog(pretty.Sprint(args...))
}

func CleanForLog(s string) string {
	return strings.Replace(s, `"`, `'`, -1)
}

func EnvOrDefault(name string, defaultVal string) string {
	envVal := os.Getenv(name)
	if envVal != "" {
		return envVal
	} else {
		return defaultVal
	}
}

func EnvOrDefaultInt(name string, defaultVal int) int {
	strVal := EnvOrDefault(name, strconv.FormatInt(int64(defaultVal), 10))
	intVal, err := strconv.ParseInt(strVal, 10, 32)
	CheckError(err)
	return int(intVal)
}
