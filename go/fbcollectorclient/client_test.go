package fbcollectorclient

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func TestProxyURL(t *testing.T) {
	ctx := context.Background()

	conf := pfconfigdriver.FingerbankSettingsProxy{
		UseProxy: "disabled",
		Host:     "test.com",
		Port:     json.Number("9999"),
	}

	if ProxyURL(ctx, conf) != nil {
		t.Error("ProxyURL with a disabled config still provided a proxy URL")
	}

	conf.UseProxy = "enabled"
	u := ProxyURL(ctx, conf)
	if u == nil {
		t.Error("ProxyURL with an enabled config didn't provide a proxy URL")
	}

	if u.Hostname() != conf.Host {
		t.Error("Unexpected hostname in ProxyURL", u.Hostname())
	}

	if u.Port() != conf.Port.String() {
		t.Error("Unexpected port in ProxyURL", u.Port())
	}

}
