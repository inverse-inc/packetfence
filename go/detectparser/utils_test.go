package detectparser

import (
	"errors"
	"testing"

	"github.com/google/go-cmp/cmp"
)

type ParseTest struct {
	Line  string
	Calls []ApiCall
	Err   error
}

func RunParseTests(p Parser, tests []ParseTest, t *testing.T) {
	for i, test := range tests {
		calls, err := p.Parse(test.Line)

		if !errors.Is(test.Err, err) {
			t.Errorf("Got expected error expected: `%v` got: `%v`", test.Err, err)
		}

		if !cmp.Equal(calls, test.Calls) {
			t.Errorf("Expected ApiCall Failed for %d) \"%s\"\n%s\n", i, test.Line, cmp.Diff(calls, test.Calls))
		}
	}
}
