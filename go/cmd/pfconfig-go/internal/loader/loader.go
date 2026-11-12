// Package loader
package loader

import (
	"os"
	"time"

	"gopkg.in/ini.v1"
)

const RootConfDir = "/usr/local/pf/conf"

type (
	// Conf will be cached
	Conf struct {
		LastRead time.Time // LastRead time of File
		File     *ini.File
	}
)

// LoadConf loads a configuration from file and its defaults if applicable.
func LoadConf(path string) (*Conf, error) {
	var err error
	var confFile *ini.File
	defaultsFilePath := path + ".defaults"
	if _, err = os.Stat(defaultsFilePath); err == nil {
		confFile, err = ini.Load(defaultsFilePath, path)
	} else {
		confFile, err = ini.Load(path)
	}
	if err != nil {
		return nil, err
	}
	return &Conf{File: confFile, LastRead: time.Now().UTC()}, nil
}

// Reload reloads the conf file from disk (with defaults)
func (c *Conf) Reload() error {
	if err := c.File.Reload(); err != nil {
		return err
	}
	c.LastRead = time.Now().UTC()
	return nil
}
