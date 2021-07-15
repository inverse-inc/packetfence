package pfconfigdriver

import (
	"fmt"
	"github.com/inverse-inc/go-utils/sharedutils"
	"testing"
	"time"
)

func TestManagementNetworkGetNetIP(t *testing.T) {
	mn := ManagementNetwork{}
	FetchDecodeSocket(ctx, &mn)
	ip, ipnet, err := mn.GetNetIP(ctx)
	sharedutils.CheckTestError(t, err)
	fmt.Println(ip, ipnet)
}

func TestStructConfig(t *testing.T) {
	sc := StructConfig{}
	now := time.Now()
	sc.SetLoadedAt(now)

	if !now.Equal(sc.PfconfigLoadedAt) {
		t.Error("SetLoadedAt doesn't set the loaded time correctly")
	}
}
