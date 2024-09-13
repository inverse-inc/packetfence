package pfcrypt

import (
	"os"

	"github.com/inverse-inc/packetfence/go/file_paths"
)

var systemInitKey []byte

func init() {
	var err error
	systemInitKey, err = os.ReadFile(file_paths.SYSTEM_INIT_KEY_FILE)
	if err != nil {
		panic(err.Error())
	}
}
