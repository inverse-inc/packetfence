package namespace

import (
	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/utils"
)

func BuildFloatingDevices(data *BuildData) error {
	for _, section := range data.Conf.File.Sections() {
		if section.Name() == "DEFAULT" {
			continue
		}
		key, err := section.GetKey("trunkPort")
		if err != nil {
			if key, err = section.NewKey("trunkPort", ""); err != nil {
				return err
			}
		}
		if utils.IsEnabled(key.MustString("")) {
			key.SetValue("1")
		} else {
			key.SetValue("0")
		}
	}
	return nil
}
