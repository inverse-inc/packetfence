package pfcrypt

import (
	"bytes"
	"os/exec"
	"testing"
)

func TestRoundTrip(t *testing.T) {

	input := []byte("Hello Test")
	ciphertext, err := PfEncrypt(input)
	if err != nil {
		t.Fatalf("PfEncrypt: %s", err.Error())
	}

	output, err := PfDecrypt(ciphertext)
	if err != nil {
		t.Fatalf("PfDecrypt: %s", err.Error())
	}

	if bytes.Compare(input, output) != 0 {
		t.Fatalf("Input does not match Output")
	}

}

func TestPerl(t *testing.T) {
	expected := []byte("Hello Test")
	cmd := exec.Command("perl", "-I/usr/local/pf/lib", "-I/usr/local/pf/lib_perl/lib/perl5", "-Mpf::config::crypt", "-eprint pf::config::crypt::pf_encrypt('Hello Test')")
	ciphertext, err := cmd.Output()
	if err != nil {
		t.Fatalf("perl crypt: %s", err.Error())
	}

	output, err := PfDecrypt(string(ciphertext))
	if err != nil {
		t.Fatalf("PfDecrypt: %s", err.Error())
	}

	if bytes.Compare(expected, output) != 0 {
		t.Fatalf("expected does not match Output")
	}

}
