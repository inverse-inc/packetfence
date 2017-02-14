package pprof

import (
	"testing"

	"github.com/inverse-inc/packetfence/go/caddy/caddy"
)

func TestSetup(t *testing.T) {
	tests := []struct {
		input     string
		shouldErr bool
	}{
		{`pprof`, false},
		{`pprof {}`, true},
		{`pprof /foo`, true},
		{`pprof {
            a b
        }`, true},
		{`pprof
          pprof`, true},
	}
	for i, test := range tests {
		c := caddy.NewTestController("http", test.input)
		err := setup(c)
		if test.shouldErr && err == nil {
			t.Errorf("Test %v: Expected error but found nil", i)
		} else if !test.shouldErr && err != nil {
			t.Errorf("Test %v: Expected no error but found error: %v", i, err)
		}
	}
}
