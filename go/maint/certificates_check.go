package maint

import (
	"regexp"
	"time"
)

var splitByComma = regexp.MustCompile(`\s*,\s*`)

type CertificatesCheck struct {
	Task
	Delay        time.Duration
	Certificates []string
}

func NewCertificatesCheck(config map[string]interface{}) JobSetupConfig {
	return &CertificatesCheck{
		Task: Task{
			Type:         config["type"].(string),
			Status:       config["status"].(string),
			Description:  config["description"].(string),
			ScheduleSpec: config["schedule"].(string),
		},
		Certificates: splitByComma.Split(config["certificates"].(string), -1),
	}
}

func (j *CertificatesCheck) Run() {
}
