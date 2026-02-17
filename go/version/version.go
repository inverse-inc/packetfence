package version

import (
	"context"
	"fmt"
	"os"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/db"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

const confDir = "/usr/local/pf/conf"

// PfVersion represents a row in the pf_version database table.
type PfVersion struct {
	ID        int        `json:"id" gorm:"primaryKey"`
	Version   string     `json:"version"`
	CreatedAt *time.Time `json:"created_at"`
}

func (PfVersion) TableName() string {
	return "pf_version"
}

var (
	pfRelease     string
	pfReleaseOnce sync.Once

	pfVersion     string
	pfVersionOnce sync.Once
)

// VersionGetRelease returns the full release string from conf/pf-release.
// e.g. "PacketFence X.Y.Z"
func VersionGetRelease() (string, error) {
	var err error
	pfReleaseOnce.Do(func() {
		path := confDir + "/pf-release"
		var data []byte
		data, err = os.ReadFile(path)
		if err != nil {
			err = fmt.Errorf("unable to open %s: %w", path, err)
			return
		}
		pfRelease = strings.TrimSpace(string(data))
	})
	if err != nil {
		return "", err
	}
	return pfRelease, nil
}

// VersionGetCurrent returns the current PacketFence version (X.Y.Z),
// stripping the "PacketFence " prefix from the release string.
func VersionGetCurrent() (string, error) {
	var err error
	pfVersionOnce.Do(func() {
		var release string
		release, err = VersionGetRelease()
		if err != nil {
			return
		}
		pfVersion = strings.TrimPrefix(release, "PacketFence ")
	})
	if err != nil {
		return "", err
	}
	return pfVersion, nil
}

var minorVersionRe = regexp.MustCompile(`^PacketFence (\d+\.\d+)\.\d+`)

// VersionGetMinor returns the minor version (X.Y) from the release string.
func VersionGetMinor() (string, error) {
	release, err := VersionGetRelease()
	if err != nil {
		return "", err
	}
	matches := minorVersionRe.FindStringSubmatch(release)
	if len(matches) < 2 {
		return "", fmt.Errorf("unable to parse minor version from release: %s", release)
	}
	return matches[1], nil
}

func openDB(ctx context.Context) (*gorm.DB, error) {
	return gorm.Open(mysql.Open(db.ReturnURIFromConfig(ctx)), &gorm.Config{})
}

// VersionCheckDB checks whether the database schema version matches the
// current PacketFence minor version (X.Y). Returns the matching version
// string from the database, or an error.
func VersionCheckDB(ctx context.Context) (string, error) {
	logger := log.LoggerWContext(ctx)

	currentVersion, err := VersionGetCurrent()
	if err != nil {
		return "", err
	}

	// Keep only major.minor (X.Y.Z -> X.Y)
	re := regexp.MustCompile(`(\.\d+).*$`)
	minorVersion := re.ReplaceAllString(currentVersion, "$1")

	database, err := openDB(ctx)
	if err != nil {
		return "", fmt.Errorf("unable to connect to database: %w", err)
	}

	var row PfVersion
	result := database.Where("version = ?", minorVersion).First(&row)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Can't get any result from DB while trying to check for database schema version: %s", result.Error))
		return "", result.Error
	}

	return row.Version, nil
}

// VersionGetLastDB returns the last (most recent) schema version recorded
// in the database.
func VersionGetLastDB(ctx context.Context) (string, error) {
	logger := log.LoggerWContext(ctx)

	database, err := openDB(ctx)
	if err != nil {
		return "", fmt.Errorf("unable to connect to database: %w", err)
	}

	var row PfVersion
	result := database.Order("id DESC").Limit(1).First(&row)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Can't get any result from DB while trying to check for database schema version: %s", result.Error))
		return "", result.Error
	}

	return row.Version, nil
}
