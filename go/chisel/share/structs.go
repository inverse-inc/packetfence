package chshare

type RadiusCerts struct {
	LetsEncrypt     bool     `json:"lets_encrypt"`
	PrivateKey      string   `json:"private_key"`
	Ca              string   `json:"ca"`
	Certificate     string   `json:"certificate"`
	IntermediateCas []string `json:"intermediate_cas"`
}
