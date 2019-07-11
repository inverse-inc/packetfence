package httpdportalpreview

import (
	"bytes"
	"context"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"time"

	"golang.org/x/net/html"
)

type Proxy struct {
	Portal string
}

// NewProxy creates a new instance of proxy.
// It sets request logger using rLogPath as output file or os.Stdout by default.
// If whitePath of blackPath is not empty they are parsed to set endpoint lists.
func NewProxy(ctx context.Context) *Proxy {
	var p Proxy

	return &p
}

// ServeHTTP satisfy HandlerFunc interface and
// log, authorize and forward requests
func (p *Proxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	host := r.Host

	query_portal := r.URL.Query()
	if query_portal.Get("PORTAL") != "" {

		p.Portal = query_portal.Get("PORTAL")
	} else {

		cookie_portal, err := r.Cookie("PF_PORTAL")
		if err == nil {
			p.Portal = cookie_portal.Value
		}
	}

	rp := httputil.NewSingleHostReverseProxy(&url.URL{
		Scheme: "http",
		Host:   host,
	})

	rp.ModifyResponse = p.UpdateResponse

	// Uses most defaults of http.DefaultTransport with more aggressive timeouts
	rp.Transport = &http.Transport{
		Proxy: http.ProxyFromEnvironment,
		DialContext: (&net.Dialer{
			Timeout:   2 * time.Second,
			KeepAlive: 2 * time.Second,
			DualStack: true,
		}).DialContext,
		MaxIdleConns:          100,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   2 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
	}

	// Pass the context in the request
	r = r.WithContext(ctx)

	Referer := r.Header.Get("Referer")
	r.Header.Set("Referer", strings.Replace(Referer, "/portal_preview", "", -1))
	r.RequestURI = strings.Replace(r.RequestURI, "/portal_preview", "", -1)

	rp.ServeHTTP(w, r)
}

func (p *Proxy) UpdateResponse(r *http.Response) error {

	var URL []*url.URL
	var LINK []string
	location, _ := url.Parse(r.Header.Get("Location"))
	if location.Host != "" {
		location.Scheme = "https"
		// location.Scheme = r.Header.Get("X-Forwarded-Proto")
		location.Host = r.Header.Get("X-Forwarded-From-Packetfence") + ":1443"
		location.Path = "/portal_preview" + location.EscapedPath()
		r.Header["Location"] = []string{location.String()}
	} else {
		r.Header["Location"] = []string{"/portal_preview" + r.Header.Get("Location")}
	}

	expire := time.Now().AddDate(0, 0, 1)

	cookie := http.Cookie{
		Name:    "PF_PORTAL",
		Value:   p.Portal,
		Expires: expire,
		Path:    "/portal_preview",
	}

	r.Header.Add("Set-Cookie", cookie.String())

	buf, _ := ioutil.ReadAll(r.Body)

	bufCopy := bytes.NewBuffer(buf)

	z := html.NewTokenizer(bufCopy)

	for {
		tt := z.Next()

		switch {
		case tt == html.ErrorToken:
			// End of the document, we're done
			for _, v := range URL {
				urlOrig := v.String()
				v.Path = "/portal_preview" + v.EscapedPath()
				buf = bytes.Replace(buf, []byte("\""+urlOrig+"\""), []byte("\""+v.String()+"\""), -1)
			}
			for _, v := range LINK {
				buf = bytes.Replace(buf, []byte("\""+v+"\""), []byte("\""+"/portal_preview"+v+"\""), -1)
			}
			boeuf := bytes.NewBufferString("")
			boeuf.Write(buf)

			r.Body = ioutil.NopCloser(boeuf)

			r.Header["Content-Length"] = []string{fmt.Sprint(boeuf.Len())}
			return nil
		case tt == html.StartTagToken:
			t := z.Token()

			// Check if the token is an <a> or <form> tag
			isAnchor := (t.Data == "a" || t.Data == "form")
			if !isAnchor {
				continue
			}

			// Extract the href value, if there is one
			ok, link := getHref(t)
			if !ok {
				continue
			}

			// Make sure the url begines in http**
			hasProto := strings.Index(link, "http") == 0

			if hasProto {
				foundURL, _ := url.Parse(link)
				URL = append(URL, foundURL)
			} else {
				LINK = append(LINK, link)
			}
		}
	}
}

// Helper function to pull the href attribute from a Token
func getHref(t html.Token) (ok bool, href string) {
	// Iterate over all of the Token's attributes until we find an "href"
	for _, a := range t.Attr {
		switch {
		case a.Key == "href":
			href = a.Val
			ok = true
		case a.Key == "action":
			href = a.Val
			ok = true
		}
	}

	// "bare" return will return the variables (ok, href) as defined in
	// the function definition
	return
}
