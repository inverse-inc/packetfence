package builder

import (
	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/utils"
	"gopkg.in/ini.v1"
)

const (
	ConfFilePath = "/usr/local/pf/conf/floating_network_device.conf"
)

type (
	// one private struct to map ini files
	floatingDevices struct {
		IP         string `ini:"ip"`
		TrunkPort  string `ini:"trunkPort"`
		Pvid       string `ini:"pvid"`
		TaggedVlan string `ini:"taggedVlan"`
	}

	// one public struct after munging
	FloatingDevices struct {
		IP         string
		TrunkPort  string
		Pvid       string
		TaggedVlan string
		ID         int // keep track of order in file
	}

	// The main public struct, represent the whole conf file
	FloatingDevicesConf struct {
		Devices map[string]*FloatingDevices
	}
)

func (c *FloatingDevicesConf) Build(sections []*ini.Section) error {
	c.Devices = make(map[string]*FloatingDevices)
	for i, section := range sections {
		fndIni := floatingDevices{}
		if err := section.MapTo(&fndIni); err != nil {
			return err
		}
		fnd, err := munge(&fndIni)
		if err != nil {
			return err
		}
		fnd.ID = i // save the order of appearance in conf file
		// duplicate key overrides previous one
		c.Devices[section.Name()] = fnd
	}
	return nil
}

func (c *FloatingDevicesConf) A() error {
	return nil
}

func munge(fndIni *floatingDevices) (*FloatingDevices, error) {
	var fnd FloatingDevices
	fnd.IP = fndIni.IP
	fnd.Pvid = fndIni.Pvid
	fnd.TaggedVlan = fndIni.TaggedVlan
	if utils.IsEnabled(fndIni.TrunkPort) {
		fnd.TrunkPort = "1"
	} else {
		fnd.TrunkPort = "0"
	}
	return &fnd, nil
}
