// Copyright 2015 Light Code Labs, LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package caddy

import (
	"os"
	"path/filepath"
)

// AssetsPath returns the path to the folder
// where the application may store data. If
// CADDYPATH env variable is set, that value
// is used. Otherwise, the path is the result
// of evaluating "$HOME/.caddy".
func AssetsPath() string {
	if caddyPath := os.Getenv("CADDYPATH"); caddyPath != "" {
		return caddyPath
	}
	return filepath.Join(userHomeDir(), ".caddy")
}

func userHomeDir() string {
	home, _ := os.UserHomeDir()
	return home
}
