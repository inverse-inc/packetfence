package file_paths

import "path/filepath"

const PF_DIR = "/usr/local/pf"

var VAR_DIR = filepath.Join(PF_DIR, "var")
var RUN_DIR = filepath.Join(VAR_DIR, "run")
var CONF_DIR = filepath.Join(PF_DIR, "conf")
var PFQUEUE_BACKEND_SOCKET = filepath.Join(RUN_DIR, "pfqueue-backend.sock")
var SYSTEM_INIT_KEY_FILE = filepath.Join(CONF_DIR, "system_init_key")
