package remoteclients

import (
	"context"
	"net"

	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func InitGlobal() {
	ctx := context.Background()

	GlobalRemoteConnectionProfiles = NewRemoteConnectionProfiles(ctx)

	advanced := pfconfigdriver.PfConfAdvanced{}
	pfconfigdriver.FetchDecodeSocket(ctx, &advanced)
	netmask, err := advanced.ZeroTrustNetworkNetmask.Int64()
	sharedutils.CheckError(err)
	ChangeStartingIP(net.ParseIP(advanced.ZeroTrustNetworkStartingIP), int(netmask))
}
