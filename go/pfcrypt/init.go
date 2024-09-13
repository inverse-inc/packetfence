package pfcrypt

import (
	"os"

	"github.com/inverse-inc/packetfence/go/file_paths"
)

var systemInitKey []byte

func init() {
	var err error
	val := os.Getenv("PF_SYSTEM_INIT_KEY_FILE")
	if val == "" {
		systemInitKey, err = os.ReadFile(file_paths.SYSTEM_INIT_KEY_FILE)
		if err != nil {
			panic("The PF_SYSTEM_INIT_KEY_FILE environment is not" + err.Error())
		}
	} else {
		systemInitKey = []byte(val)
	}
}
