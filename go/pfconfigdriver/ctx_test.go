package pfconfigdriver

import (
	"context"
	"fmt"
	"testing"
)

func TestContext(t *testing.T) {
	PfConfigStorePool.AddStruct(context.Background(), "PfConfGeneral", &PfConfGeneral{})
	ctx := NewContext(context.Background())
	i := GetConfigFromContext(ctx, "PfConfGeneral")
	if config, ok := i.(*PfConfGeneral); !ok {
		fmt.Printf("config %#v\n", config)
		t.Fatalf("PfConfGeneral did not return")
	}
}
