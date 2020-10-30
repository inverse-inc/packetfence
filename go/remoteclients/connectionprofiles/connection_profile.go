package connectionprofiles

import (
	"context"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

type RemoteConnectionProfile struct {
	pfconfigdriver.StructConfig
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"config::RemoteProfiles"`
	PfconfigHashNS string `val:"-"`

	Description                string   `json:"description"`
	Enabled                    string   `json:"enabled"`
	BasicFilterType            string   `json:"basic_filter_type"`
	BasicFilterValue           string   `json:"basic_filter_value"`
	AdvancedFilter             string   `json:"advanced_filter"`
	Scanners                   []string `json:"scanners"`
	AllowCommunicationSameRole string   `json:"allow_communication_same_role"`
	AllowCommunicationToRoles  []string `json:"allow_communication_to_roles"`
}

type FilterInfo struct {
	NodeInfo     common.NodeInfo
	RemoteClient remoteclients.RemoteClient
}

func (rcp *RemoteConnectionProfile) init(ctx context.Context) {

}

// Instantiate a new RemoteConnectionProfile given its configuration ID in PacketFence
func Instantiate(ctx context.Context, id string) (RemoteConnectionProfile, error) {
	rcp := RemoteConnectionProfile{}
	rcp.PfconfigHashNS = id
	_, err := pfconfigdriver.FetchDecodeSocketCache(ctx, &rcp)
	if err != nil {
		return nil, err
	}
	rcp.PfconfigHashNS = id
	_, err = pfconfigdriver.FetchDecodeSocketCache(ctx, &rcp)
	if err != nil {
		return nil, err
	}

	err = rcp.init(ctx)
	if err != nil {
		return nil, err
	}

	return rcp, nil
}
