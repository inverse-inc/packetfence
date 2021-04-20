package firewallsso

import (
	"github.com/inverse-inc/go-utils/sharedutils"
	"testing"
)

func TestIbossGetRequest(t *testing.T) {
	f := NewFactory(ctx)
	fw, err := f.Instantiate(ctx, "testfw")
	iboss := fw.(*Iboss)
	sharedutils.CheckTestError(t, err)

	login, err := iboss.getRequest(ctx, "login", sampleInfo)
	sharedutils.CheckTestError(t, err)

	expected := "http://testfw:8015/nacAgent?action=login&user=lzammit&dc=Packetfence&key=XS832CF2A&ip=1.2.3.4&cn=lzammit&g=default"
	if login.URL.String() != expected {
		t.Errorf("Iboss login generated URL is not correct. %s instead of %s", login.URL, expected)
	}

	logout, err := iboss.getRequest(ctx, "logout", sampleInfo)
	sharedutils.CheckTestError(t, err)

	expected = "http://testfw:8015/nacAgent?action=logout&user=lzammit&dc=Packetfence&key=XS832CF2A&ip=1.2.3.4&cn=lzammit&g=default"
	if logout.URL.String() != expected {
		t.Errorf("Iboss login generated URL is not correct. %s instead of %s", login.URL, expected)
	}

	expected = "application/x-www-form-urlencoded"
	if logout.Header.Get("Content-Type") != expected {
		t.Errorf("Wrong content type for iboss request. %s instead of %s", logout.Header.Get("Content-Type"), expected)
	}
}
