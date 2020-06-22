package maint

import (
	"crypto/x509"
	"encoding/pem"
	"errors"
	"io/ioutil"
	"regexp"
	"time"
)

var splitByComma = regexp.MustCompile(`\s*,\s*`)

type CertificatesCheck struct {
	Task
	Delay        string
	Certificates []string
}

type UnVerifyFileCert struct {
	Path    string
	Message string
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
	j.VerifyCertFiles(j.Certificates)
}

func (j *CertificatesCheck) VerifyCertFiles(files []string) {
	invalid := []error{}
	for _, file := range files {
		if err := j.VerifyFile(file); err != nil {
            invalid = append(invalid, err)
		}
	}

	//    j.SendEmails(unverifiedCerts)
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
	if now.After(cert.NotAfter) {
		return errors.New("SSL certificate is expired. This should be addressed to avoid issues.")
	}

	return nil
}
