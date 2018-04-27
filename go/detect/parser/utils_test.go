package parser

import (
	"github.com/google/go-cmp/cmp"
	"testing"
)

type ParseTest struct {
	Line  string
	Calls []ApiCall
}

func RunParseTests(p Parser, tests []ParseTest, t *testing.T) {
	for i, test := range tests {
		calls, err := p.Parse(test.Line)
		if err != nil {
			t.Errorf("Error Parsing %d) %s: %v", i, test.Line)
			continue
		}

		if !cmp.Equal(calls, test.Calls) {
			t.Errorf("Expected ApiCall Failed for %d %v) %s", i, test.Line, calls)
		}
	}
}
