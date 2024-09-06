package pfconfigdriver

import (
	"context"
	"testing"
)

func TestAddGetType(t *testing.T) {
	AddType[PfConfAdvanced](context.Background())
	v := GetType[PfConfAdvanced](context.Background())
	if v.HashingCost != "8" {
		t.Fatalf("Got %s instead %s", v.HashingCost, "8")
	}
}
