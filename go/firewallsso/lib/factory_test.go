package libfirewallsso

import (
	"testing"
)

func TestInstantiate(t *testing.T) {
	f := NewFactory()
	f.Instantiate("test")
}
