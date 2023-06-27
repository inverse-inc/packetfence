package common

type DNSAuditLog struct {
	Ip     string `json:"ip"`
	Mac    string `json:"mac"`
	Qname  string `json:"qname"`
	Qtype  string `json:"qtype"`
	Scope  string `json:"scope"`
	Answer string `json:"answer"`
}
