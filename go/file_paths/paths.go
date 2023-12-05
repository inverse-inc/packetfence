package file_paths

import "path/filepath"

const PF_DIR = "/usr/local/pf"

var VAR_DIR = filepath.Join(PF_DIR, "var")
var RUN_DIR = filepath.Join(VAR_DIR, "run")
var PFQUEUE_BACKEND_SOCKET = filepath.Join(RUN_DIR, "pfqueue-backend.sock")
