package discovernetworkdevice

import (
	"context"

	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

type Switches struct {
	Group   string `json:"group"`
	Options []struct {
		Supports []string `json:"supports"`
		Text     string   `json:"text"`
		Value    string   `json:"value"`
		DriverId string   `json:"driver_id"`
	} `json:"options"`
}

type PayloadModules struct {
	Meta struct {
		Type struct {
			Allowed []Switches `json:"allowed"`
		} `json:"type"`
	} `json:"meta"`
}

func GetSwitchModules(ctx context.Context) ([]Switches, error) {
	apiClient := unifiedapiclient.NewFromConfig(ctx)
	var data PayloadModules
	err := apiClient.Call(ctx, "OPTIONS", "/api/v1/config/switches", &data)
	if err != nil {
		return nil, err
	}
	return data.Meta.Type.Allowed, nil
}
