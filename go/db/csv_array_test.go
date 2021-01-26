package db

import (
	"reflect"
	"testing"
)

func TestScan(t *testing.T) {
	tests := "a,b,c"
	a := CsvArray{}
	a.Scan(&tests)
	if !reflect.DeepEqual([]string(a), []string{"a", "b", "c"}) {
		t.Errorf("'%s' was not parsed properly", tests)
	}
}
