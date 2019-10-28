package pfpki

import (
	"encoding/json"
	"io/ioutil"
	"net/http"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/sharedutils"
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
	name     string `json:"profile_name,omitempty"`
	ca       string `json:"ca_name,omitempty"`
	validity string `json:"validity,omitempty"`
	keyType string `json:"key_type,omitempty"`
	keySize string `json:"key_size,omitempty"`
	digest string `json:"digest,omitempty"`
	keyUsage string `json:"key_usage,omitempty"`
	extendedKeyUsage string `json:"extended_key_usage,omitempty"`
	p12SmtpServer string `json:"p12_smtp_server,omitempty"`
	p12MailPassword string `json:"p12_mail_password,omitempty"`
	p12MailSubject string `json:"p12_mail_subject,omitempty"`
	p12MailFrom string `json:"p12_mail_from,omitempty"`
	p12MailHeader string `json:"p12_mail_header,omitempty"`
	p12MailFooter string `json:"p12_mail_footer,omitempty"`
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
