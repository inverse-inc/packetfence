package main

import (
	"crypto/tls"
	"flag"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"sync"
)

type Jar struct {
	lk      sync.Mutex
	cookies map[string][]*http.Cookie
}

func NewJar() *Jar {
	jar := new(Jar)
	jar.cookies = make(map[string][]*http.Cookie)
	return jar
}

// SetCookies handles the receipt of the cookies in a reply for the
// given URL.  It may or may not choose to save the cookies, depending
// on the jar's policy and implementation.
func (jar *Jar) SetCookies(u *url.URL, cookies []*http.Cookie) {
	jar.lk.Lock()
	jar.cookies[u.Host] = cookies
	jar.lk.Unlock()
}

// Cookies returns the cookies to send in a request for the given URL.
// It is up to the implementation to honor the standard cookie use
// restrictions such as in RFC 6265.
func (jar *Jar) Cookies(u *url.URL) []*http.Cookie {
	return jar.cookies[u.Host]
}

func main() {

	var portal string
	flag.StringVar(&portal, "portal", "", "Portal URL like http://100.64.0.2")
	flag.Parse()

	if len(portal) == 0 {
		fmt.Println("Usage: register_node -portal")
		flag.PrintDefaults()
		os.Exit(1)
	}

	tr := &http.Transport{
		TLSClientConfig: &tls.Config{
			PreferServerCipherSuites: true,
			InsecureSkipVerify:       true,
		},
	}

	jar := NewJar()

	client := http.Client{tr, nil, jar, 0}

	resp, err := client.Get(portal + "/captive-portal")

	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}

	resp, err = client.Get(portal + "/switchto/default_policy+default_registration_policy+default_login_policy")

	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}

	defer resp.Body.Close()

	resp, err = client.PostForm(portal+"/signup", url.Values{
		"fields[username]": {"iastigmate"},
		"fields[password]": {"password"},
		"fields[aup]":      {"1"},
		"submit":           {""},
	})

	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}

}
