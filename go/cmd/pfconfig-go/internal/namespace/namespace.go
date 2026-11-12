// Package namespace contains optionnal function to parse/alter/translate/munge data
// from ini files to memory
package namespace

import (
	"strings"

	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/loader"
)

type (
	// BuildData contains all deps to build a namespace
	BuildData struct {
		Conf *loader.Conf            // the actual conf to be built
		Deps map[string]*loader.Conf // any other used conf to build the current conf
	}

	BuildFunc = func(data *BuildData) error

	NamespaceType int

	// NamespaceInfos contains static data (loaded at startup then read-only)
	// about all managed namespaces
	NamespaceInfos struct {
		Name           string    // name::space (as PrimaryKey)
		Path           string    // config file path relative path to pf/conf folder (updated to absolute full path at startup)
		Build          BuildFunc // optionnal munging function
		ChildResources []string  // child resources namespaces (any reload of the conf then rebuild its child resources)
		DepResources   []string  // dependencies on other namespaces (injected at Build())
		// always -import .defaults, always -envsubst values
	}
)

const (
	NamespaceUnknown NamespaceType = iota
	NamespaceConfig
	NamespaceResource
	NamespaceInterface
	NamespaceFilterEngine
)

func (n *NamespaceInfos) Type() NamespaceType {
	if strings.HasPrefix(n.Name, "config") {
		return NamespaceConfig
	} else if strings.HasPrefix(n.Name, "resource") {
		return NamespaceResource
	} else if strings.HasPrefix(n.Name, "interfaces") {
		return NamespaceInterface
	} else if strings.HasPrefix(n.Name, "FilterEngine") { // TODO: check on that
		return NamespaceFilterEngine
	} else {
		return NamespaceUnknown // should never happens, but check anyway
	}
}

// NamespaceDefinitions contains definitions of all managed namespaces
var NamespaceDefinitions = []NamespaceInfos{
	{
		Name:  "config::FloatingDevices",
		Path:  "floating_network_device.conf",
		Build: BuildFloatingDevices,
	},
	{
		Name: "config::Cloud",
		Path: "cloud.conf",
	},
	{
		Name:           "config::Ssl",
		Path:           "ssl.conf",
		ChildResources: []string{"resource::eap_config"},
		DepResources:   []string{"config::Cloud"}, // TODO: for testing
	},
}
