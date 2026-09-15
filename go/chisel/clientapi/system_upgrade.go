package clientapi

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"regexp"

	"github.com/inverse-inc/go-utils/log"
)

// Remote upgrade: the client cannot run apt itself (it lives inside the
// container), so it drops a trigger file in the conf dir shared with the
// host; the packetfence-pfconnector-upgrade.path systemd unit on the host
// picks it up, points the PacketFence apt repository at the requested
// version and upgrades the packetfence-pfconnector-remote package. Only
// packages signed by the PacketFence archive keyring can ever be installed.

// defaultUpgradeTriggerFile is the in-container path of the trigger; the
// container's /usr/local/pf/conf is the host's
// /usr/local/pfconnector-remote/conf.
const defaultUpgradeTriggerFile = "/usr/local/pf/conf/upgrade_requested"

// upgradeVersionRe is deliberately strict: the value ends up in a
// root-written apt configuration on the host.
var upgradeVersionRe = regexp.MustCompile(`^[0-9]+\.[0-9]+$`)

func upgradeTriggerFile() string {
	if path := os.Getenv("PFCONNECTOR_UPGRADE_TRIGGER_FILE"); path != "" {
		return path
	}
	return defaultUpgradeTriggerFile
}

// systemUpgrade validates the requested PacketFence version and hands it to
// the host through the trigger file. The upgrade itself (and its result) is
// asynchronous: the host logs to conf/upgrade.log and the new package
// restarts the connector, so the reported version confirms the outcome.
func systemUpgrade(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			Version string `json:"version"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid request body", http.StatusBadRequest)
			return
		}
		if !upgradeVersionRe.MatchString(req.Version) {
			http.Error(w, "Invalid version, expected MAJOR.MINOR", http.StatusBadRequest)
			return
		}

		trigger := upgradeTriggerFile()
		// Write-then-rename so the host's path unit only ever sees a
		// complete trigger file.
		tmp := filepath.Join(filepath.Dir(trigger), ".upgrade_requested.tmp")
		if err := os.WriteFile(tmp, []byte(req.Version+"\n"), 0600); err != nil {
			log.LoggerWContext(api.ctx).Error(fmt.Sprintf("Failed to write upgrade trigger: %v", err))
			http.Error(w, "Failed to write the upgrade trigger", http.StatusInternalServerError)
			return
		}
		if err := os.Rename(tmp, trigger); err != nil {
			log.LoggerWContext(api.ctx).Error(fmt.Sprintf("Failed to publish upgrade trigger: %v", err))
			http.Error(w, "Failed to publish the upgrade trigger", http.StatusInternalServerError)
			return
		}

		log.LoggerWContext(api.ctx).Info(fmt.Sprintf("Upgrade to PacketFence %s requested through the pfconnector-client API", req.Version))
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, `{"message": "Upgrade to %s scheduled"}`, req.Version)
	})
}
