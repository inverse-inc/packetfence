package connectionprofiles

import (
	"context"
	"fmt"

	"github.com/inverse-inc/packetfence/go/common"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/remoteclients"
)

const DefaultRemoteConnectionProfile = "default"

var simpleFilters = map[string]func(rcp RemoteConnectionProfile, fi FilterInfo) bool{
	"filter_device": func(rcp RemoteConnectionProfile, fi FilterInfo) bool {
		return fi.NodeInfo.MAC == rcp.BasicFilterValue
	},
	"filter_role": func(rcp RemoteConnectionProfile, fi FilterInfo) bool {
		return fi.NodeInfo.Category == rcp.BasicFilterValue
	},
	"filter_user": func(rcp RemoteConnectionProfile, fi FilterInfo) bool {
		return fi.NodeInfo.PID == rcp.BasicFilterValue
	},
}

type RemoteConnectionProfiles struct {
	pfconfigdriver.CachedHash
}

func NewRemoteConnectionProfiles(ctx context.Context) *RemoteConnectionProfiles {
	rcp := &RemoteConnectionProfiles{}
	rcp.PfconfigNS = "config::RemoteProfiles"
	rcp.New = rcp.newProfile
	return rcp
}

func (rcp *RemoteConnectionProfiles) newProfile(ctx context.Context, id string) (pfconfigdriver.PfconfigObject, error) {
	profile := &RemoteConnectionProfile{}
	_, err := pfconfigdriver.FetchDecodeSocketCache(ctx, profile)
	if err != nil {
		return nil, err
	}
	profile.init(ctx)
	return profile, nil
}

func (rcp *RemoteConnectionProfiles) All(ctx context.Context) map[string]*RemoteConnectionProfile {
	profiles := map[string]*RemoteConnectionProfile{}
	for id, o := range rcp.Structs {
		profiles[id] = o.(*RemoteConnectionProfile)
	}
	return profiles
}

func (rcp *RemoteConnectionProfiles) Get(ctx context.Context, id string) *RemoteConnectionProfile {
	return rcp.Structs[id].(*RemoteConnectionProfile)
}

func (rcp *RemoteConnectionProfiles) InstantiateForClient(ctx context.Context, fi FilterInfo) *RemoteConnectionProfile {
	for id, profile := range rcp.All(ctx) {
		if profile.filterForClient(ctx, fi) {
			log.LoggerWContext(ctx).Info(fmt.Sprintf("Matched remote connection profile %s for %s", id, fi.NodeInfo.MAC))
			return profile
		}
	}
	return nil
}

type RemoteConnectionProfile struct {
	pfconfigdriver.StructConfig
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"config::RemoteProfiles"`
	PfconfigHashNS string `val:"-"`

	Description                string   `json:"description"`
	Status                     string   `json:"status"`
	BasicFilterType            string   `json:"basic_filter_type"`
	BasicFilterValue           string   `json:"basic_filter_value"`
	AdvancedFilter             string   `json:"advanced_filter"`
	Scanners                   []string `json:"scanners"`
	AllowCommunicationSameRole string   `json:"allow_communication_same_role"`
	AllowCommunicationToRoles  []string `json:"allow_communication_to_roles"`
}

type FilterInfo struct {
	NodeInfo     *common.NodeInfo
	RemoteClient *remoteclients.RemoteClient
}

func (rcp *RemoteConnectionProfile) init(ctx context.Context) {

}

func (rcp *RemoteConnectionProfile) filterForClient(ctx context.Context, fi FilterInfo) bool {
	if rcp.PfconfigHashNS == DefaultRemoteConnectionProfile {
		return true
	}

	if filter, ok := simpleFilters[rcp.BasicFilterType]; ok {
		if filter(*rcp, fi) {
			return true
		}
	} else if rcp.BasicFilterType != "" {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Invalid basic filter type %s for profile %s", rcp.BasicFilterType, rcp.PfconfigHashNS))
	}

	return false

	//TODO: handle advanced filter here through pffilter
}
