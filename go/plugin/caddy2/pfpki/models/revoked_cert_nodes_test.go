package models

import (
	"reflect"
	"testing"

	"golang.org/x/crypto/ocsp"
)

func TestSerialsMatch(t *testing.T) {
	cases := []struct {
		node, pki string
		want      bool
	}{
		{"03", "3", true},
		{"3", "3", true},
		{"0x03", "3", true},
		{"2900000051d6270165ddbd8d20000100000051", "914330553564675120330438658068338585366429777", true},
		{"29:00:00:00:51", "176093659217", true},
		{"FF", "255", true},
		{"03", "4", false},
		{"N/A", "3", false},
		{"", "3", false},
		{"zz", "3", false},
		{"03", "", false},
	}
	for _, c := range cases {
		if got := serialsMatch(c.node, c.pki); got != c.want {
			t.Errorf("serialsMatch(%q, %q) = %v, want %v", c.node, c.pki, got, c.want)
		}
	}
}

func TestIssuerHasCN(t *testing.T) {
	escaped := `\\/C=CA\\/ST=QC\\/L=Montreal\\/O=STG\\/OU=Inverse\\/CN=CaKamai`
	if !issuerHasCN(escaped, "CaKamai") {
		t.Error("escaped node_tls issuer should match its CN")
	}
	if !issuerHasCN("/C=CA/O=STG/CN=CaKamai", "CaKamai") {
		t.Error("plain issuer should match its CN")
	}
	if !issuerHasCN("C=CA, O=STG, CN=CaKamai", "CaKamai") {
		t.Error("comma separated issuer should match its CN")
	}
	if issuerHasCN(escaped, "CaKamai352") || issuerHasCN(`\\/CN=CaKamai352`, "CaKamai") {
		t.Error("a CA whose name only starts the same must not match")
	}
	if issuerHasCN(escaped, "") {
		t.Error("an empty CA name must not match")
	}
}

func TestMacsOfCert(t *testing.T) {
	rows := []nodeTLS{
		{Mac: "02:44:45:4c:80:17", TLSClientCertSerial: "03", TLSClientCertIssuer: `\\/O=STG\\/CN=CaKamai`},
		{Mac: "02:a1:57:a0:00:11", TLSClientCertSerial: "03", TLSClientCertIssuer: `\\/O=Akamai\\/CN=AkaCA`},
		{Mac: "02:44:45:4c:80:18", TLSClientCertSerial: "04", TLSClientCertIssuer: `\\/O=STG\\/CN=CaKamai`},
		{Mac: "02:44:45:4c:80:19", TLSClientCertSerial: "0x3", TLSClientCertIssuer: `/O=STG/CN=CaKamai`},
	}
	cert := Cert{Cn: "jbon", SerialNumber: "3", CaName: "CaKamai"}
	got := macsOfCert(rows, cert)
	want := []string{"02:44:45:4c:80:17", "02:44:45:4c:80:19"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("macsOfCert = %v, want %v (same serial from another CA must not match)", got, want)
	}
}

func TestShouldDeregisterOnRevocation(t *testing.T) {
	if shouldDeregisterOnRevocation(ocsp.Superseded) {
		t.Error("a superseded (expired or renewed) certificate must not deregister its nodes")
	}
	for _, reason := range []int{ocsp.Unspecified, ocsp.KeyCompromise, ocsp.AffiliationChanged, ocsp.CessationOfOperation, ocsp.CertificateHold} {
		if !shouldDeregisterOnRevocation(reason) {
			t.Errorf("reason %d should deregister the nodes", reason)
		}
	}
}
