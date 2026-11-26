package namespace

import "fmt"

func BuildTest(data *BuildData) (any, error) {
	conf, _ := NewScalarData(data)
	tmp, ok := data.Deps["config::FloatingDevices"]
	if !ok {
		return nil, fmt.Errorf("missing dependency %s", "config::FloatingDevices")
	}
	fdConf := tmp.(*HashData)
	conf.Value = fdConf.Sections["11:22:33:44:55:66"]["ip"]
	return conf, nil
}
