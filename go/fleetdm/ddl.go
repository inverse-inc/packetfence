package fleetdm

import "time"

type User struct {
	CreatedAt          time.Time     `json:"created_at"`
	UpdatedAt          time.Time     `json:"updated_at"`
	Id                 int           `json:"id"`
	Name               string        `json:"name"`
	Email              string        `json:"email"`
	Enabled            bool          `json:"enabled"`
	ForcePasswordReset bool          `json:"force_password_reset"`
	GravatarUrl        string        `json:"gravatar_url"`
	SsoEnabled         bool          `json:"sso_enabled"`
	GlobalRole         string        `json:"global_role"`
	Teams              []interface{} `json:"teams"`
}

type Host struct {
	CreatedAt                 time.Time   `json:"created_at"`
	UpdatedAt                 time.Time   `json:"updated_at"`
	Id                        int         `json:"id"`
	DetailUpdatedAt           time.Time   `json:"detail_updated_at"`
	LastRestartedAt           time.Time   `json:"last_restarted_at"`
	SoftwareUpdatedAt         time.Time   `json:"software_updated_at"`
	LabelUpdatedAt            time.Time   `json:"label_updated_at"`
	PolicyUpdatedAt           time.Time   `json:"policy_updated_at"`
	LastEnrolledAt            time.Time   `json:"last_enrolled_at"`
	SeenTime                  time.Time   `json:"seen_time"`
	Hostname                  string      `json:"hostname"`
	Uuid                      string      `json:"uuid"`
	Platform                  string      `json:"platform"`
	OsqueryVersion            string      `json:"osquery_version"`
	OsVersion                 string      `json:"os_version"`
	Build                     string      `json:"build"`
	PlatformLike              string      `json:"platform_like"`
	CodeName                  string      `json:"code_name"`
	Uptime                    int64       `json:"uptime"`
	Memory                    int64       `json:"memory"`
	CpuType                   string      `json:"cpu_type"`
	CpuSubtype                string      `json:"cpu_subtype"`
	CpuBrand                  string      `json:"cpu_brand"`
	CpuPhysicalCores          int         `json:"cpu_physical_cores"`
	CpuLogicalCores           int         `json:"cpu_logical_cores"`
	HardwareVendor            string      `json:"hardware_vendor"`
	HardwareModel             string      `json:"hardware_model"`
	HardwareVersion           string      `json:"hardware_version"`
	HardwareSerial            string      `json:"hardware_serial"`
	ComputerName              string      `json:"computer_name"`
	DisplayName               string      `json:"display_name"`
	PublicIp                  string      `json:"public_ip"`
	PrimaryIp                 string      `json:"primary_ip"`
	PrimaryMac                string      `json:"primary_mac"`
	DistributedInterval       int         `json:"distributed_interval"`
	ConfigTlsRefresh          int         `json:"config_tls_refresh"`
	LoggerTlsPeriod           int         `json:"logger_tls_period"`
	Additional                interface{} `json:"additional"`
	Status                    string      `json:"status"`
	DisplayText               string      `json:"display_text"`
	TeamId                    interface{} `json:"team_id"`
	TeamName                  interface{} `json:"team_name"`
	GigsDiskSpaceAvailable    float64     `json:"gigs_disk_space_available"`
	PercentDiskSpaceAvailable interface{} `json:"percent_disk_space_available"`
	GigsTotalDiskSpace        interface{} `json:"gigs_total_disk_space"`
	PackStats                 interface{} `json:"pack_stats"`
}

type LoginResponse struct {
	User  User   `json:"user"`
	Token string `json:"token"`
}

type HostResponse struct {
	Host `json:"host"`
}
