package util

import (
	"fmt"
	"runtime"
	"testing"
)

func CheckError(err error) {
	if err != nil {
		panic(err)
	}
}

func CheckTestError(t *testing.T, err error) {
	if err != nil {
		_, file, no, _ := runtime.Caller(1)
		t.Error(fmt.Sprintf("There was an error '%s' called from %s#%d", err, file, no))
	}
}
