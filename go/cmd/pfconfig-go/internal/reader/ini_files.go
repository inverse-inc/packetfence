package reader

import (
	"path/filepath"

	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/utils"
	"gopkg.in/ini.v1"
)

type (
	IniFile struct {
		File *ini.File
		Path string
	}

	Buildable interface {
		Build([]*ini.Section) error
	}

	Conf[N Buildable] struct {
		iniFile *IniFile
		Ns      N
	}
)

func LoadIniFile(filePath string) (*IniFile, error) {
	cleanPath := filepath.Clean(filePath)
	iniFile, err := ini.Load(cleanPath)
	if err != nil {
		return nil, err
	}
	return &IniFile{File: iniFile, Path: cleanPath}, nil
}

func LoadIniFiles(filePaths []string) (map[string]*IniFile, error) {
	iniFiles := make(map[string]*IniFile)
	for _, filePath := range filePaths {
		iniFile, err := LoadIniFile(filePath)
		if err != nil {
			return nil, err
		}
		iniFiles[filepath.Base(iniFile.Path)] = iniFile
	}
	return iniFiles, nil
}

func (i *IniFile) Filename() string {
	return filepath.Base(i.Path)
}

func LoadConf[N Buildable](confPath string) (*Conf[N], error) {
	iniFile, err := LoadIniFile(confPath)
	if err != nil {
		return nil, err
	}
	conf := Conf[N]{
		iniFile: iniFile,
		Ns:      utils.NewValueFromType[N](),
	}
	if err := conf.Ns.Build(iniFile.File.Sections()); err != nil {
		return nil, err
	}
	return &conf, nil
}

func (c *Conf[N]) Reload() error {
	iniFile := c.iniFile.File
	if err := iniFile.Reload(); err != nil {
		return err
	}
	if err := c.Ns.Build(iniFile.Sections()); err != nil {
		return err
	}
	return nil
}

func (c *Conf[N]) Rebuild() error {
	return c.Ns.Build(c.iniFile.File.Sections())
}
