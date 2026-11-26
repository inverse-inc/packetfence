// Package namespace contains optionnal function to parse/alter/translate/munge data
// from ini files to memory
package namespace

import (
	"errors"
	"strings"

	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/loader"
)

type (
	HashData struct {
		Sections        map[string]map[string]string // {section: {param: value, ...}, ...}
		SectionsOrdered []string                     // keep the order of section in file
	}

	ScalarData struct {
		Value string
	}

	ArrayData struct {
		Values []string
	}

	// BuildData contains all data to build a namespace
	BuildData struct {
		Data any            // optionnal initial data (actually data from conf file, else empty)
		Deps map[string]any // any other used namespaces (from cache) to build the current namespace, read-only, DO NOT EDIT HERE
		Args []string       // overlay params
	}

	BuildFunc = func(data *BuildData) (any, error)

	NamespaceType int

	// NamespaceInfos contains static data (loaded at startup then read-only)
	// about all managed namespaces
	NamespaceInfos struct {
		Path         *string   // config file path relative path to pf/conf folder (updated to absolute full path at startup)
		Name         string    // name::space (as PrimaryKey)
		Build        BuildFunc // build function
		DepResources []string  // dependencies on other namespaces (injected at Build())
		// always -import .defaults, always -envsubst values
	}
)

const (
	NamespaceUnknown NamespaceType = iota
	NamespaceConfig
	NamespaceResource
	NamespaceInterfaces
	NamespaceFilterEngine
)

func (n *NamespaceInfos) Type() NamespaceType {
	if strings.HasPrefix(n.Name, "config") {
		return NamespaceConfig
	} else if strings.HasPrefix(n.Name, "resource") {
		return NamespaceResource
	} else if strings.HasPrefix(n.Name, "interfaces") {
		return NamespaceInterfaces
	} else if strings.HasPrefix(n.Name, "FilterEngine") { // TODO: check on that
		return NamespaceFilterEngine
	} else {
		return NamespaceUnknown // should never happens, but check anyway
	}
}

func NewHashData(data *BuildData) (*HashData, error) {
	var err error
	var outData HashData
	if data.Data != nil {
		switch tmp := data.Data.(type) {
		case *loader.Conf:
			outData.SectionsOrdered = tmp.SectionsOrdered
			outData.Sections = tmp.Sections
		default:
			err = errors.New("bad data type from BuidData")
		}
	} else {
		outData.Sections = make(map[string]map[string]string, 0)
	}
	return &outData, err
}

func NewArrayData(data *BuildData) (*ArrayData, error) {
	return &ArrayData{Values: make([]string, 0)}, nil
}

func NewScalarData(data *BuildData) (*ScalarData, error) {
	return &ScalarData{}, nil
}

func DefaultBuildFromConf(data *BuildData) (any, error) {
	return NewHashData(data)
}

// NamespaceDefinitions contains definitions of all managed namespaces
var NamespaceDefinitions = []NamespaceInfos{
	{
		Name:  "config::FloatingDevices",
		Path:  new("floating_network_device.conf"),
		Build: BuildFloatingDevices,
	},
	{
		Name:  "config::Cloud",
		Path:  new("cloud.conf"),
		Build: DefaultBuildFromConf,
	},
	{
		Name:         "config::Ssl",
		Path:         new("ssl.conf"),
		DepResources: []string{"config::Cloud"}, // TODO: for testing
		Build:        DefaultBuildFromConf,
	},
	{
		Name:         "resource::Test", // TODO: for testing
		Build:        BuildTest,
		DepResources: []string{"config::FloatingDevices"},
	},
}
