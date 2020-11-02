package connectionprofiles

import (
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
