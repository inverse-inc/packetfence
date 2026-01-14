package discovernetworkdevice

import (
	"context"

	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

type ModuleOption struct {
	Supports []string `json:"supports"`
	Text     string   `json:"text"`
	Value    string   `json:"value"`
	DriverId string   `json:"driver_id"`
}

// SwitchModules contains the list of all modules available for a specific vendor (Group)
// Use "Group", Value" and "DriverId" to match a switch with a module.
// "Supports" and "Text" are not used.
type SwitchModules struct {
	Group   string         `json:"group"`
	Options []ModuleOption `json:"options"`
}

// payloadModules represents the data returned by "config/switches" endpoint.
// It contains only fields we need.
type payloadModules struct {
	Meta struct {
		Type struct {
			Allowed []SwitchModules `json:"allowed"`
		} `json:"type"`
	} `json:"meta"`
}

// GetSwitchModules return a list of available switch modules in PF
func GetSwitchModules(ctx context.Context) ([]SwitchModules, error) {
	apiClient := unifiedapiclient.NewFromConfig(ctx)
	var data payloadModules
	err := apiClient.Call(ctx, "OPTIONS", "/api/v1/config/switches", &data)
	if err != nil {
		return nil, err
	}
	return data.Meta.Type.Allowed, nil
}

func FilterSwitchModules(modules []SwitchModules, vendor, os, driver string) any {
	for _, mod := range modules {
		// find the vendor group
		if mod.Group == vendor && len(driver) > 0 {
			// now find if a driver can be match
			for _, opt := range mod.Options {
				if opt.DriverId == driver {
					// only one to be returned
					return []SwitchModules{
						SwitchModules{
							Group:   mod.Group,
							Options: []ModuleOption{opt},
						},
					}
				}
			}
			// return all vendor list
			return []SwitchModules{mod}
		}
	}
	// no match, return all
	return modules
}
