package connectionprofiles

import (
	"context"
	"testing"

	"github.com/inverse-inc/packetfence/go/common"
)

func TestSimpleFilters(t *testing.T) {
	fi := FilterInfo{
		NodeInfo: &common.NodeInfo{
			Node: common.Node{
				MAC: "00:11:22:33:44:55",
				PID: "bob",
			},
			Category: "guest",
		},
	}

	rcp := RemoteConnectionProfile{
		BasicFilterType:  "filter_device",
		BasicFilterValue: fi.NodeInfo.MAC,
	}

	if !simpleFilters["filter_device"](rcp, fi) {
		t.Error("Filter that should match didn't match")
	}

	rcp = RemoteConnectionProfile{
		BasicFilterType:  "filter_device",
		BasicFilterValue: "aa:bb:cc:dd:ee:ff",
	}

	if simpleFilters["filter_device"](rcp, fi) {
		t.Error("Filter that shouldn't match did match")
	}

	rcp = RemoteConnectionProfile{
		BasicFilterType:  "filter_role",
		BasicFilterValue: fi.NodeInfo.Category,
	}

	if !simpleFilters["filter_role"](rcp, fi) {
		t.Error("Filter that should match didn't match")
	}

	rcp = RemoteConnectionProfile{
		BasicFilterType:  "filter_role",
		BasicFilterValue: "default",
	}

	if simpleFilters["filter_role"](rcp, fi) {
		t.Error("Filter that shouldn't match did match")
	}

	rcp = RemoteConnectionProfile{
		BasicFilterType:  "filter_user",
		BasicFilterValue: fi.NodeInfo.PID,
	}

	if !simpleFilters["filter_user"](rcp, fi) {
		t.Error("Filter that should match didn't match")
	}

	rcp = RemoteConnectionProfile{
		BasicFilterType:  "filter_user",
		BasicFilterValue: "default",
	}

	if simpleFilters["filter_user"](rcp, fi) {
		t.Error("Filter that shouldn't match did match")
	}

}

func TestRemoteConnectionProfilesStruct(t *testing.T) {
	ctx := context.Background()
	rcp := NewRemoteConnectionProfiles(ctx)

	all := rcp.All(ctx)

	if len(all) != 3 {
		t.Error("Wrong length for the remote profiles:", len(all))
	}

	expected := []string{
		"zammitcorp_IT",
		"zammitcorp_Marketing",
		"default",
	}

	for i, expectedVal := range expected {
		if all[i].PfconfigHashNS != expectedVal {
			t.Errorf("Unexpected ID at position %d. Got %s instead of %s", i, all[i].PfconfigHashNS, expectedVal)
		}
	}
}

func TestRemoteConnectionProfilesInstantiateForClient(t *testing.T) {
	ctx := context.Background()
	rcp := NewRemoteConnectionProfiles(ctx)

	// Test matching on the first profile
	fi := FilterInfo{
		NodeInfo: &common.NodeInfo{
			Node: common.Node{
				MAC: "00:11:22:33:44:55",
				PID: "bob",
			},
			Category: "IT",
		},
	}

	profile := rcp.InstantiateForClient(ctx, fi)

	if profile.PfconfigHashNS != "zammitcorp_IT" {
		t.Error("Unexpected profile from InstantiateForClient", profile.PfconfigHashNS)
	}

	// Will still yield IT because of top to bottom priority
	fi.NodeInfo.PID = "marketing\\\\bob"

	profile = rcp.InstantiateForClient(ctx, fi)

	if profile.PfconfigHashNS != "zammitcorp_IT" {
		t.Error("Unexpected profile from InstantiateForClient", profile.PfconfigHashNS)
	}

	// Should now yield the marketing profile now that IT doesn't match anymore
	fi.NodeInfo.PID = "marketing\\\\bob"
	fi.NodeInfo.Category = "Marketing"

	profile = rcp.InstantiateForClient(ctx, fi)

	if profile.PfconfigHashNS != "zammitcorp_Marketing" {
		t.Error("Unexpected profile from InstantiateForClient", profile.PfconfigHashNS)
	}

	// Test default profile matching
	fi = FilterInfo{
		NodeInfo: &common.NodeInfo{
			Node: common.Node{
				MAC: "00:11:22:33:44:55",
			},
		},
	}

	profile = rcp.InstantiateForClient(ctx, fi)

	if profile.PfconfigHashNS != DefaultRemoteConnectionProfile {
		t.Error("Unexpected profile from InstantiateForClient", profile.PfconfigHashNS)
	}

}
