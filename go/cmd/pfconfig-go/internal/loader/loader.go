// Package loader
package loader

import (
	"os"
	"time"

	"gopkg.in/ini.v1"
)

const RootConfDir = "/usr/local/pf/conf"

type (
	Conf struct {
		LastRead        time.Time                    // LastRead time of File
		Sections        map[string]map[string]string // {section: {param: value, ...}, ...}
		SectionsOrdered []string                     // keep original order of sections in file
	}
)

// LoadConf loads a configuration from file and its defaults if applicable.
func LoadConf(path string) (*Conf, error) {
	var err error
	var confFile *ini.File
	defaultsFilePath := path + ".defaults"
	ini.DefaultSection = "__DEFAULT__" // some conf have [DEFAULT] sections, so use an other one
	if _, err = os.Stat(defaultsFilePath); err == nil {
		confFile, err = ini.Load(defaultsFilePath, path)
	} else {
		confFile, err = ini.Load(path)
	}
	if err != nil {
		return nil, err
	}
	iniSections := confFile.Sections()
	sections := make(map[string]map[string]string, len(iniSections)-1)
	sectionsOrdered := make([]string, 0, len(iniSections)-1)
	for _, section := range iniSections {
		sectionName := section.Name()
		if sectionName == ini.DefaultSection {
			// TODO: log if default not empty
			continue // ignore default, should be empty
		}
		sections[sectionName] = section.KeysHash()
		sectionsOrdered = append(sectionsOrdered, sectionName)
	}
	return &Conf{LastRead: time.Now().UTC(), Sections: sections, SectionsOrdered: sectionsOrdered}, nil
}

// HasSection check if a section exists
func (c *Conf) HasSection(key string) bool {
	_, ok := c.Sections[key]
	return ok
}

// GetSection returns a single section if any, works like a map
func (c *Conf) GetSection(key string) (map[string]string, bool) {
	v, ok := c.Sections[key]
	return v, ok
}

// GetSections return the list of section data in file order
// Allocate an array of map
func (c *Conf) GetSections() []map[string]string {
	tmp := make([]map[string]string, 0, len(c.SectionsOrdered))
	for _, sectionName := range c.SectionsOrdered {
		section := c.Sections[sectionName]
		tmp = append(tmp, section)
	}
	return tmp
}

// GetSectionsKeys returns the list of section names in file order
func (c *Conf) GetSectionsKeys() []string {
	return c.SectionsOrdered
}
