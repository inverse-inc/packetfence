package maint

import (
	"context"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io/ioutil"
	"regexp"
	"time"

	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
	"github.com/inverse-inc/packetfence/go/util"
)

var splitByComma = regexp.MustCompile(`\s*,\s*`)

type CertificatesCheck struct {
	Task
	Delay         string
	DelayDuration time.Duration
	Certificates  []string
}

type UnVerifyFileCert struct {
	Path    string
	Message string
}

func NewCertificatesCheck(config map[string]interface{}) JobSetupConfig {
	delay := config["delay"].(string)
	duration, _ := util.NormalizeTime(delay)
	return &CertificatesCheck{
		Task: Task{
			Type:         config["type"].(string),
			Status:       config["status"].(string),
			Description:  config["description"].(string),
			ScheduleSpec: config["schedule"].(string),
		},
		Certificates:  splitByComma.Split(config["certificates"].(string), -1),
		Delay:         delay,
		DelayDuration: duration,
	}
}

func (j *CertificatesCheck) Run() {
	j.VerifyCertFiles(j.Certificates)
}

func (j *CertificatesCheck) VerifyCertFiles(files []string) {
	certErrors := []error{}
	for _, file := range files {
		if err := j.VerifyFile(file); err != nil {
			certErrors = append(certErrors, err)
		}
	}

	j.SendEmails(certErrors)
}

func (j *CertificatesCheck) VerifyFile(file string) error {
	contents, err := ioutil.ReadFile(file)
	if err != nil {
		return err
	}

	return j.VerifyContents(file, contents)
}

func (j *CertificatesCheck) VerifyContents(file string, contents []byte) error {
	var block *pem.Block
	var rest []byte
	for {
		block, rest = pem.Decode(contents)
		if block == nil {
			return errors.New("No Certificate data found")
		}

		if block.Type == "CERTIFICATE" {
			break
		} else {
			contents = rest
		}
	}

	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return err
	}

	return j.VerifyCert(file, cert)
}

func (j *CertificatesCheck) VerifyCert(file string, cert *x509.Certificate) error {
	now := time.Now()
	notAfter := cert.NotAfter
	if now.After(notAfter) {
		return fmt.Errorf("SSL certificate '%s' is expired. This should be addressed to avoid issues.", file)
	}

	now = now.Add(j.DelayDuration)
	if now.After(notAfter) {
		return fmt.Errorf("SSL certificate '%s' is about to expire soon (less than '%s'). This should be taken care.", file, j.Delay)
	}

	return nil
}

func (j *CertificatesCheck) SendEmails(messages []error) {
	ctx := context.Background()
	empty := struct{}{}
	apiClient := unifiedapiclient.NewFromConfig(ctx)
	payload := map[string]string{"subject": "SSL certificate expiration"}
	for _, msg := range messages {
		payload["message"] = msg.Error()
		data, err := json.Marshal(payload)
		err = apiClient.CallWithStringBody(ctx, "POST", "/api/v1/emails/pfmailer", string(data), &empty)
		if err != nil {
			log.LoggerWContext(ctx).Error("API error: " + err.Error())
		}
	}
}
