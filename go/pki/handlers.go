package main

import (
	"encoding/json"
	"io/ioutil"
	"net/http"
)

// PostOptionsNewCA struct
type PostOptionsNewCA struct {
	CAName        string `json:"caname,omitempty"`
	Organization  string `json:"organization,omitempty"`
	Country       string `json:"country,omitempty"`
	Province      string `json:"province,omitempty"`
	Locality      string `json:"locality,omitempty"`
	StreetAddress string `json:"streetAddress,omitempty"`
	PostalCode    string `json:"postalCode,omitempty"`
}

// PostOptionsProfile struct
type PostOptionsProfile struct {
	Name             string `json:"profile_name,omitempty"`
	Ca               string `json:"ca_name,omitempty"`
	Validity         string `json:"validity,omitempty"`
	KeyType          string `json:"key_type,omitempty"`
	KeySize          string `json:"key_size,omitempty"`
	Digest           string `json:"digest,omitempty"`
	KeyUsage         string `json:"key_usage,omitempty"`
	ExtendedKeyUsage string `json:"extended_key_usage,omitempty"`
	P12SmtpServer    string `json:"p12_smtp_server,omitempty"`
	P12MailPassword  string `json:"p12_mail_password,omitempty"`
	P12MailSubject   string `json:"p12_mail_subject,omitempty"`
	P12MailFrom      string `json:"p12_mail_from,omitempty"`
	P12MailHeader    string `json:"p12_mail_header,omitempty"`
	P12MailFooter    string `json:"p12_mail_footer,omitempty"`
}

// Info struct
type Info struct {
	Status string `json:"status"`
	CA     string `json:"mac,omitempty"`
}

func newCA(res http.ResponseWriter, req *http.Request) {
	// ctx := req.Context()

	body, err := ioutil.ReadAll(req.Body)
	if err != nil {
		panic(err)
	}
	var o PostOptionsNewCA

	err = json.Unmarshal(body, &o)
	if err != nil {
		panic(err)
	}

	CA := o.CAName

	// if CA == nil {
	// 	handleError(res, http.StatusBadRequest)
	// 	return
	// }

	var result = map[string][]*Info{
		"result": {
			&Info{CA: CA, Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}
