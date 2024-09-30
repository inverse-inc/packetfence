package pfcrypt

import (
	"fmt"
	"os"

	"github.com/inverse-inc/packetfence/go/file_paths"
)

var systemInitKey []byte
var dervivedKey []byte

func setupSystemInitKey(envName, fileName string) error {
	val := os.Getenv(envName)
	if val != "" {
		systemInitKey = []byte(val)
		return nil
	}

	var err error
	systemInitKey, err = os.ReadFile(file_paths.SYSTEM_INIT_KEY_FILE)
	if err != nil {
		return fmt.Errorf("Cannot find key in env %s or file %s :%w", envName, fileName, err)
	}

	return nil
}

func init() {
	if err := setupSystemInitKey("PF_SYSTEM_INIT_KEY", file_paths.SYSTEM_INIT_KEY_FILE); err != nil {
		panic("Unable to setup the PF_SYSTEM_INIT secret" + err.Error())
	}

	dervivedKey = makeDerivedKey()
}
