package namespace

import (
	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/utils"
)

func BuildFloatingDevices(data *BuildData) (any, error) {
	conf, err := NewHashData(data)
	if err != nil {
		return nil, err
	}
	for _, section := range conf.Sections {
		key, ok := section["trunkPort"]
		if !ok {
			key = "0"
		}
		if utils.IsEnabled(key) {
			section["trunkPort"] = "1"
		} else {
			section["trunkPort"] = "0"
		}
	}
	return conf, nil
}
