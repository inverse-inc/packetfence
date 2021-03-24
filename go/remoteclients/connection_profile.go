package remoteclients

import (
	"context"
	"fmt"

	"github.com/inverse-inc/packetfence/go/common"
	"github.com/inverse-inc/packetfence/go/filter_client"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

var pffilter = filter_client.NewClient()

var GlobalRemoteConnectionProfiles *RemoteConnectionProfiles

const DefaultRemoteConnectionProfile = "default"

type RemoteConnectionProfiles struct {
	pfconfigdriver.CachedHash
	orderedIds struct {
		pfconfigdriver.StructConfig
		PfconfigMethod string `val:"element"`
		PfconfigNS     string `val:"resource::remote_profiles_keys"`
		PfconfigArray  string `val:"yes"`
		Element        []string
	}
}

func NewRemoteConnectionProfiles(ctx context.Context) *RemoteConnectionProfiles {
	rcp := &RemoteConnectionProfiles{}
	rcp.PfconfigNS = "config::RemoteProfiles"
	rcp.New = rcp.newProfile
	rcp.Refresh(ctx)
	return rcp
}

func (rcp *RemoteConnectionProfiles) newProfile(ctx context.Context, id string) (pfconfigdriver.PfconfigObject, error) {
	profile := &RemoteConnectionProfile{}
	profile.PfconfigHashNS = id
	_, err := pfconfigdriver.FetchDecodeSocketCache(ctx, profile)
	if err != nil {
		return nil, err
	}
	profile.init(ctx)
	return profile, nil
}

func (rcp *RemoteConnectionProfiles) AllEnabled(ctx context.Context) []*RemoteConnectionProfile {
	profiles := rcp.All(ctx)
	enabledProfiles := []*RemoteConnectionProfile{}
	for _, profile := range profiles {
		if sharedutils.IsEnabled(profile.Status) {
			enabledProfiles = append(enabledProfiles, profile)
		}
	}
	return enabledProfiles
}

func (rcp *RemoteConnectionProfiles) All(ctx context.Context) []*RemoteConnectionProfile {
	pfconfigdriver.FetchDecodeSocketCache(ctx, &rcp.orderedIds)
	profiles := make([]*RemoteConnectionProfile, len(rcp.orderedIds.Element))
	i := 0
	for _, id := range rcp.orderedIds.Element {
		if id == DefaultRemoteConnectionProfile {
			continue
		}
		profiles[i] = rcp.Get(ctx, id)
		i++
	}
	profiles[len(profiles)-1] = rcp.Get(ctx, DefaultRemoteConnectionProfile)
	return profiles
}

func (rcp *RemoteConnectionProfiles) Get(ctx context.Context, id string) *RemoteConnectionProfile {
	return rcp.Structs[id].(*RemoteConnectionProfile)
}

func (rcp *RemoteConnectionProfiles) InstantiateForClient(ctx context.Context, fi FilterInfo) *RemoteConnectionProfile {
	info, err := pffilter.FilterRemoteProfile("instantiate", fi)
	sharedutils.CheckError(err)
	profileId := info.(map[string]interface{})["profile"].(string)
	log.LoggerWContext(ctx).Info(fmt.Sprintf("Instantiate profile %s for MAC: %s, username: %s, role: %s", profileId, fi.NodeInfo.MAC, fi.NodeInfo.PID, fi.NodeInfo.Category))
	return rcp.Get(ctx, profileId)
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
	AllowCommunicationSameRole string   `json:"allow_communication_same_role"`
	AllowCommunicationToRoles  []string `json:"allow_communication_to_roles"`
	ResolveHostnamesOfPeers    string   `json:"resolve_hostnames_of_peers"`
	AdditionalDomainsToResolve []string `json:"additional_domains_to_resolve"`
	Routes                     []string `json:"routes"`
	Gateway                    string   `json:"gateway"`
	STUNServer                 string   `json:"stun_server"`
	InternalDomainToResolve    string   `json:"internal_domain_to_resolve"`
}

type FilterInfo struct {
	NodeInfo     *common.NodeInfo `json:"node_info"`
	RemoteClient *RemoteClient    `json:"remote_client"`
}

func (rcp *RemoteConnectionProfile) init(ctx context.Context) {

}
