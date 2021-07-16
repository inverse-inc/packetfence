package httpdportalpreview

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
	"golang.org/x/net/html"
)

// Proxy structure
type Proxy struct {
	Portal string
	Uri    string
	Ctx    context.Context
}

// NewProxy creates a new instance of proxy.
// It sets request logger using rLogPath as output file or os.Stdout by default.
// If whitePath of blackPath is not empty they are parsed to set endpoint lists.
func NewProxy(ctx context.Context) *Proxy {
	p := &Proxy{}

	return p
}

// ServeHTTP satisfy HandlerFunc interface and
// log, authorize and forward requests
func (p *Proxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	p.Ctx = ctx
	// Needs to be splitted but dirty patch first
	//host := r.Host
	previewStatic := false

	params, _ := getParams(`/config/profile/(?P<Profile>.*)/preview/(?P<File>.*)`, r.RequestURI)

	if _, ok := params["Profile"]; ok {
		p.Portal = params["Profile"]
		p.Uri = r.RequestURI
		previewStatic = true
	} else {
		queryPortal := r.URL.Query()
		if queryPortal.Get("PORTAL") != "" {

			p.Portal = queryPortal.Get("PORTAL")
		} else {

			cookiePortal, err := r.Cookie("PF_PORTAL")
			if err == nil {
				p.Portal = cookiePortal.Value
			}
		}
	}

	rp := httputil.NewSingleHostReverseProxy(&url.URL{
		Scheme: "http",
		Host:   "127.0.0.1",
	})
	// It's not a file preview
	if previewStatic {
		rp.ModifyResponse = p.ServeStatic
	} else {
		rp.ModifyResponse = p.UpdateResponse
	}

	// Uses most defaults of http.DefaultTransport with more aggressive timeouts
	rp.Transport = &http.Transport{
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
	if previewStatic {
		r.URL = &url.URL{Path: "/captive-portal"}
	}
	rp.ServeHTTP(w, r)
}

// ServeStatic rewrite the portal response
func (p *Proxy) ServeStatic(r *http.Response) error {
	apiClient := unifiedapiclient.NewFromConfig(context.Background())
	params, _ := getParams(`/config/profile/(?P<Profile>.*)/preview/(?P<File>.*)`, p.Uri)

	buffer, _ := apiClient.CallSimpleHtml(p.Ctx, "GET", "/api/v1/config/connection_profile/"+params["Profile"]+"/preview/"+params["File"], "")

	p.RewriteAnswer(r, buffer)
	return nil
}

// UpdateResponse rewrite the portal response
func (p *Proxy) RewriteAnswer(r *http.Response, buff []byte) error {
	var URL []*url.URL
	var LINK []string
	location, _ := url.Parse(r.Header.Get("Location"))
	if location.Host != "" {

		r.Header["Location"] = []string{"/portal_preview" + location.EscapedPath()}
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

	bufCopy := bytes.NewBuffer(buff)

	z := html.NewTokenizer(bufCopy)

	for {
		tt := z.Next()

		switch {
		case tt == html.ErrorToken:
			// End of the document, we're done
			for _, v := range URL {
				urlOrig := v.String()
				v.Path = "/portal_preview" + v.EscapedPath()
				buff = bytes.Replace(buff, []byte("\""+urlOrig+"\""), []byte("\""+v.String()+"\""), -1)
			}
			for _, v := range LINK {
				if strings.HasPrefix(v, "/") {
					buff = bytes.Replace(buff, []byte("\""+v+"\""), []byte("\""+"/portal_preview"+v+"\""), -1)
				} else {
					buff = bytes.Replace(buff, []byte("\""+v+"\""), []byte("\""+"/portal_preview/captive-portal"+v+"\""), -1)
				}
			}
			boeuf := bytes.NewBufferString("")
			boeuf.Write(buff)

			r.Body = ioutil.NopCloser(boeuf)

			r.Header["Content-Length"] = []string{fmt.Sprint(boeuf.Len())}
			return nil
		case tt == html.StartTagToken, tt == html.SelfClosingTagToken:
			t := z.Token()
			// Check if the token is an <a> or <form> tag
			isAnchor := (t.Data == "a" || t.Data == "form" || t.Data == "link" || t.Data == "img" || t.Data == "script")

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

// UpdateResponse rewrite the portal response
func (p *Proxy) UpdateResponse(r *http.Response) error {

	buf, _ := ioutil.ReadAll(r.Body)
	p.RewriteAnswer(r, buf)
	return nil
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
		case a.Key == "src":
			href = a.Val
			ok = true
		}
	}

	// "bare" return will return the variables (ok, href) as defined in
	// the function definition
	return
}

func getParams(regEx, url string) (paramsMap map[string]string, err error) {

	var compRegEx = regexp.MustCompile(regEx)
	match := compRegEx.FindStringSubmatch(url)
	err = errors.New("Doesn't match")
	paramsMap = make(map[string]string)
	for i, name := range compRegEx.SubexpNames() {
		if i > 0 && i <= len(match) {
			err = nil
			paramsMap[name] = match[i]
		}
	}
	return
}
