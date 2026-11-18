package uiplugins

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// Error answers a JSON error like the PacketFence API
func Error(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(struct {
		Message string `json:"message"`
		Status  int    `json:"status"`
	}{message, status})
}

// ProxyMethods are the HTTP methods routed to the proxy: the verbs of the
// catalog API methods, and PUT for the bundle plugins (api-aaa authorizes no
// other). Allowed refuses the ones a manifest does not declare
var ProxyMethods = []string{http.MethodGet, http.MethodOptions, http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete}

// the admin actions every plugin shares (lib/pf/constants/admin_roles.pm)
const (
	PluginReadAction  = "PLUGIN_READ"
	PluginWriteAction = "PLUGIN_WRITE"
)

// the action a passed through request needs, by HTTP method
var passthroughActions = map[string]string{
	http.MethodGet:     PluginReadAction,
	http.MethodOptions: PluginReadAction,
	http.MethodPost:    PluginWriteAction,
	http.MethodPut:     PluginWriteAction,
	http.MethodPatch:   PluginWriteAction,
	http.MethodDelete:  PluginWriteAction,
}

// ErrReadOnly refuses a write while the database is read-only (a cluster
// member that lost the quorum, a read-only replica), like the PacketFence API
var ErrReadOnly = errors.New("the database is read-only, changes are not allowed")

// IsWrite tells if a request changes something on the plugin: for a bundle
// the write methods, for a manifest page create, update and delete (a POST
// search is a read)
func IsWrite(m *Manifest, method, path string) bool {
	if m.IsBundle() {
		return passthroughActions[method] == PluginWriteAction
	}
	switch APIMethodOf(m, method, path) {
	case "create", "update", "delete":
		return true
	}
	return false
}

// the manifest API methods a request can be, by HTTP method (the fixed verbs
// of the catalog)
var apiMethodsByVerb = map[string][]string{
	http.MethodGet:     {"list", "item"},
	http.MethodOptions: {"listOptions", "itemOptions"},
	http.MethodPost:    {"search", "create"},
	http.MethodPatch:   {"update"},
	http.MethodDelete:  {"delete"},
}

// ProxyPath is the path of a request to a plugin, on the plugin service:
// what follows /api/v1/plugin/<name>, still URL encoded (an item id the UI
// encoded can hold a "/", eg: items/site%2Fa). false when the request is not
// for that plugin. The name is the router's, decoded: it is compared with the
// decoded name segment (acm%65 is acme).
func ProxyPath(r *http.Request, name string) (string, bool) {
	const prefix = "/api/v1/plugin/"
	escaped := r.URL.EscapedPath()
	if !strings.HasPrefix(escaped, prefix) {
		return "", false
	}
	rest := escaped[len(prefix):]
	end := strings.Index(rest, "/")
	if end < 0 {
		return "", false
	}
	if segment, err := url.PathUnescape(rest[:end]); err != nil || segment != name {
		return "", false
	}
	return rest[end:], true
}

// a decoded path, or a decoded {id}, that cannot move out of where it is
// sent: none of its "/" separated parts is "." or "..", nor empty unless
// allowEmpty. The plugin gets the decoded path too, and a router or a
// path.Clean of it must not land on another endpoint than the one allowed.
func safeDecoded(decoded string, allowEmpty bool) bool {
	for _, part := range strings.Split(decoded, "/") {
		if part == "." || part == ".." || (part == "" && !allowEmpty) {
			return false
		}
	}
	return true
}

// does a request path (URL encoded) match a manifest API path, segment by
// segment: a literal segment is compared with the raw text, as the plugin
// gets it (items/%73earch is not items/search); {id} is one raw segment that
// decodes to a safe value: it may hold a "/" (site%2Fa), no empty, "." or ".."
// part (x%2F..%2F..)
func pathMatches(template, path string) bool {
	t := strings.Split(strings.TrimPrefix(template, "/"), "/")
	s := strings.Split(strings.TrimPrefix(path, "/"), "/")
	if len(t) != len(s) {
		return false
	}
	for i := range t {
		if t[i] != "{id}" {
			if t[i] != s[i] {
				return false
			}
			continue
		}
		id, err := url.PathUnescape(s[i])
		if err != nil || !safeDecoded(id, false) {
			return false
		}
	}
	return true
}

// APIMethodOf is the manifest API method a request is, "" when the manifest
// does not declare it
func APIMethodOf(m *Manifest, method, path string) string {
	for _, name := range apiMethodsByVerb[method] {
		if a, found := m.API[name]; found && pathMatches(a.Path, path) {
			return name
		}
	}
	return ""
}

// Allowed checks a request against the manifest: it must be one of the API
// methods the manifest declares (path and verb), the admin must satisfy
// menu.can, and the can of the method for create, update and delete.
func Allowed(m *Manifest, method, path string, actions map[string]bool) error {
	if !m.Menu.Can.Allowed(actions) {
		return errors.New("the admin roles do not satisfy menu.can")
	}
	apiMethod := APIMethodOf(m, method, path)
	if apiMethod == "" {
		return fmt.Errorf("%s %s is not an API method of the manifest", method, path)
	}
	if a := m.API[apiMethod]; !a.Can.Allowed(actions) {
		return fmt.Errorf("the admin roles do not satisfy api.%s.can", apiMethod)
	}
	return nil
}

// AllowedPassthrough checks a request to a bundle plugin: the admin must
// satisfy menu.can, and have PLUGIN_READ for GET and OPTIONS, PLUGIN_WRITE
// for POST, PUT, PATCH and DELETE. The path, once decoded, cannot hold a "."
// or ".." part, even from an encoded "/" (x%2F..%2Fother).
func AllowedPassthrough(m *Manifest, method, path string, actions map[string]bool) error {
	if !m.Menu.Can.Allowed(actions) {
		return errors.New("the admin roles do not satisfy menu.can")
	}
	action, found := passthroughActions[method]
	if !found {
		return fmt.Errorf("%s is not allowed", method)
	}
	decoded, err := url.PathUnescape(path)
	if err != nil || !safeDecoded(strings.TrimPrefix(decoded, "/"), true) {
		return fmt.Errorf("invalid path %s", path)
	}
	if !actions[action] {
		return fmt.Errorf("%s %s needs the admin action %s", method, path, action)
	}
	return nil
}

// AdminRoles are the admin roles api-aaa sets in X-PacketFence-Admin-Roles
// (the names of the roles, eg: ALL, not their actions)
func AdminRoles(r *http.Request) []string {
	roles := []string{}
	for _, role := range strings.Split(r.Header.Get("X-PacketFence-Admin-Roles"), ",") {
		if role = strings.TrimSpace(role); role != "" {
			roles = append(roles, role)
		}
	}
	return roles
}

// Identity is the admin a request to a plugin is made for, as api-aaa checked
// it
type Identity struct {
	Username string
	Roles    []string
	Actions  map[string]bool
}

// IdentityOf is the identity api-aaa set on a request, with the actions of its
// roles
func IdentityOf(r *http.Request, actions map[string]bool) Identity {
	return Identity{Username: r.Header.Get("X-PacketFence-Username"), Roles: AdminRoles(r), Actions: actions}
}

// the identity headers passed to a plugin
const (
	UsernameHeader = "X-PacketFence-Username"
	RolesHeader    = "X-PacketFence-Admin-Roles"
	ActionsHeader  = "X-PacketFence-Admin-Actions"
)

// isIdentityLike tells if a request header could be read as an identity
// header by a plugin: X-PacketFence-* in any case, with "_" for "-" (CGI and
// WSGI servers map both to HTTP_X_PACKETFENCE_*)
func isIdentityLike(name string) bool {
	n := strings.ReplaceAll(strings.ToLower(name), "_", "-")
	return strings.HasPrefix(n, "x-packetfence-")
}

// the headers of the admin request that are not passed to a plugin: the admin
// token never is
var pluginDroppedHeaders = []string{"Authorization", "Cookie", "Proxy-Authorization", "Accept-Encoding"}

// limits of a request to a plugin
const (
	maxProxyBody     = 10 << 20
	maxProxyDuration = 60 * time.Second
)

// the headers of a plugin answer: only its JSON content, under the PacketFence
// origin it cannot be a page, set cookies or open CORS
func answerHeaders(contentLength int64) http.Header {
	h := http.Header{}
	h.Set("Content-Type", "application/json")
	h.Set("X-Content-Type-Options", "nosniff")
	h.Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; sandbox")
	h.Set("Cache-Control", "no-store")
	if contentLength >= 0 {
		h.Set("Content-Length", strconv.FormatInt(contentLength, 10))
	}
	return h
}

// errPluginAnswer is a plugin answer that is not passed to the admin
type errPluginAnswer struct{ reason string }

func (e errPluginAnswer) Error() string { return e.reason }

// checkAnswer replaces the headers of a plugin answer: a redirect, an
// authentication challenge (which the UI would read as the end of the admin
// session) or anything else than JSON is refused
func checkAnswer(resp *http.Response) error {
	switch {
	case resp.StatusCode >= 300 && resp.StatusCode < 400:
		return errPluginAnswer{fmt.Sprintf("answered a redirect (%d)", resp.StatusCode)}
	case resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusProxyAuthRequired:
		return errPluginAnswer{fmt.Sprintf("answered %d", resp.StatusCode)}
	case resp.ContentLength > maxProxyBody:
		return errPluginAnswer{fmt.Sprintf("answer larger than %d bytes", maxProxyBody)}
	}
	// the answer is read whole (up to the limit) and checked as JSON before
	// anything is sent to the admin
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxProxyBody+1))
	resp.Body.Close()
	if err != nil {
		return err
	}
	if len(data) > maxProxyBody {
		return errPluginAnswer{fmt.Sprintf("answer larger than %d bytes", maxProxyBody)}
	}
	if len(data) > 0 {
		mediaType, _, err := mime.ParseMediaType(resp.Header.Get("Content-Type"))
		if err != nil || (mediaType != "application/json" && !strings.HasSuffix(mediaType, "+json")) {
			return errPluginAnswer{fmt.Sprintf("answered %q, not JSON", resp.Header.Get("Content-Type"))}
		}
		if !json.Valid(data) {
			return errPluginAnswer{"answered invalid JSON"}
		}
	}
	resp.Header = answerHeaders(int64(len(data)))
	resp.Body = io.NopCloser(bytes.NewReader(data))
	resp.ContentLength = int64(len(data))
	return nil
}

// checkPassthroughAnswer replaces the headers of the answer of a bundle
// plugin. Redirects and authentication challenges are refused, as for a
// manifest page. A JSON answer is passed as JSON; anything else is passed as
// a download (Content-Disposition: attachment, its own media type), never as
// a page of the PacketFence origin.
func checkPassthroughAnswer(resp *http.Response) error {
	switch {
	case resp.StatusCode >= 300 && resp.StatusCode < 400:
		return errPluginAnswer{fmt.Sprintf("answered a redirect (%d)", resp.StatusCode)}
	case resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusProxyAuthRequired:
		return errPluginAnswer{fmt.Sprintf("answered %d", resp.StatusCode)}
	case resp.ContentLength > maxProxyBody:
		return errPluginAnswer{fmt.Sprintf("answer larger than %d bytes", maxProxyBody)}
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxProxyBody+1))
	resp.Body.Close()
	if err != nil {
		return err
	}
	if len(data) > maxProxyBody {
		return errPluginAnswer{fmt.Sprintf("answer larger than %d bytes", maxProxyBody)}
	}
	h := answerHeaders(int64(len(data)))
	mediaType, _, err := mime.ParseMediaType(resp.Header.Get("Content-Type"))
	isJSON := err == nil && (mediaType == "application/json" || strings.HasSuffix(mediaType, "+json"))
	if len(data) > 0 && !isJSON {
		if err != nil || mediaType == "" {
			mediaType = "application/octet-stream"
		}
		h.Set("Content-Type", mediaType)
		disposition := "attachment"
		if _, params, err := mime.ParseMediaType(resp.Header.Get("Content-Disposition")); err == nil && params["filename"] != "" {
			disposition = mime.FormatMediaType("attachment", map[string]string{"filename": params["filename"]})
		}
		h.Set("Content-Disposition", disposition)
	}
	resp.Header = h
	resp.Body = io.NopCloser(bytes.NewReader(data))
	resp.ContentLength = int64(len(data))
	return nil
}

// Proxy passes a request to the plugin service of a registration: path is the
// path on the plugin service, URL encoded (ProxyPath), identity the admin
// api-aaa checked. The request
// is checked with Allowed against the manifest of the plugin, from the cache
// of the Fetcher. The plugin gets the identity headers (its X-PacketFence-*
// headers are only these), never the admin token. Its answer must be JSON:
// it is passed with fixed headers. A plugin whose manifest is unavailable,
// that does not answer, or answers something else is a 502.
//
// A bundle plugin (template "bundle", accepted only when its package
// installed a bundle, see BundleInstalled) is passed through: any path, checked
// with AllowedPassthrough, any content type, for up to its bundle.timeout. A
// write (IsWrite) is refused while readOnly says the database is read-only.
func (f *Fetcher) Proxy(w http.ResponseWriter, r *http.Request, registration Registration, path string, identity Identity, readOnly func(context.Context) bool) {
	name := registration.Name
	manifest := f.Manifest(r.Context(), registration)
	if manifest == nil {
		Error(w, http.StatusBadGateway, fmt.Sprintf("The plugin %q is unavailable", name))
		return
	}
	timeout := maxProxyDuration
	allowed, answer, rt := Allowed, checkAnswer, http.RoundTripper(roundTripper{})
	if manifest.IsBundle() {
		timeout = manifest.PassthroughTimeout()
		allowed, answer, rt = AllowedPassthrough, checkPassthroughAnswer, passthroughRoundTripper{}
	}
	ctx, cancel := context.WithTimeout(r.Context(), timeout)
	defer cancel()
	r = r.WithContext(ctx)
	if err := allowed(manifest, r.Method, path, identity.Actions); err != nil {
		Error(w, http.StatusForbidden, fmt.Sprintf("Plugin %q: %s", name, err))
		return
	}
	if IsWrite(manifest, r.Method, path) && readOnly != nil && readOnly(ctx) {
		Error(w, http.StatusForbidden, fmt.Sprintf("Plugin %q: %s", name, ErrReadOnly))
		return
	}
	// Allowed and AllowedPassthrough decoded it: the whole path decodes
	decoded, err := url.PathUnescape(path)
	if err != nil {
		Error(w, http.StatusBadRequest, fmt.Sprintf("Plugin %q: invalid path", name))
		return
	}
	if r.ContentLength > maxProxyBody {
		Error(w, http.StatusRequestEntityTooLarge, fmt.Sprintf("A request to a plugin is limited to %d bytes", maxProxyBody))
		return
	}
	// read whole (at most maxProxyBody): the signature covers its SHA-256
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxProxyBody))
	if err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			Error(w, http.StatusRequestEntityTooLarge, fmt.Sprintf("A request to a plugin is limited to %d bytes", maxProxyBody))
			return
		}
		Error(w, http.StatusBadRequest, fmt.Sprintf("Plugin %q: the request body could not be read", name))
		return
	}
	bodySHA256 := BodySHA256(body)
	r.Body = io.NopCloser(bytes.NewReader(body))
	r.ContentLength = int64(len(body))
	if len(body) == 0 {
		r.Body = http.NoBody
	}
	target, err := url.Parse(registration.BaseURL())
	if err != nil {
		Error(w, http.StatusBadGateway, err.Error())
		return
	}
	actions := strings.Join(manifest.ActionsFor(f.Catalog, identity.Actions), ",")
	proxy := &httputil.ReverseProxy{
		Transport: rt,
		Rewrite: func(pr *httputil.ProxyRequest) {
			pr.Out.URL.Scheme = target.Scheme
			pr.Out.URL.Host = target.Host
			// the encoding of the admin request is kept (an id with a "/")
			pr.Out.URL.Path = decoded
			pr.Out.URL.RawPath = path
			pr.Out.URL.RawQuery = pr.In.URL.RawQuery
			pr.Out.Host = target.Host
			for _, header := range pluginDroppedHeaders {
				pr.Out.Header.Del(header)
			}
			// only the identity set here: not the client's, whatever their
			// spelling, and not lost to a Connection header listing them
			for header := range pr.Out.Header {
				if isIdentityLike(header) {
					delete(pr.Out.Header, header)
				}
			}
			pr.Out.Header.Set(UsernameHeader, identity.Username)
			pr.Out.Header.Set(RolesHeader, strings.Join(identity.Roles, ","))
			pr.Out.Header.Set(ActionsHeader, actions)
			// a bundle plugin is the code of a package installed on the
			// server: its own calls to the PacketFence API run with the token,
			// and the rights, of the admin
			if manifest.IsBundle() {
				if token := pr.In.Header.Get("Authorization"); token != "" {
					pr.Out.Header.Set(AdminTokenHeader, token)
				}
			}
			// the plugin checks that the request comes from PacketFence
			signed := SignedRequest{
				Method:     pr.Out.Method,
				Path:       pr.Out.URL.EscapedPath(),
				Query:      pr.Out.URL.RawQuery,
				Username:   identity.Username,
				Roles:      strings.Join(identity.Roles, ","),
				Actions:    actions,
				BodySHA256: bodySHA256,
			}
			if ts, sig := signHeaders(name, signed, time.Now()); sig != "" {
				pr.Out.Header.Set(TimestampHeader, ts)
				pr.Out.Header.Set(SignatureHeader, sig)
			}
			pr.SetXForwarded()
		},
		ModifyResponse: answer,
		ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
			f.log(ctx, fmt.Sprintf("UI plugin %q: %s", name, err))
			var tooLarge *http.MaxBytesError
			if errors.As(err, &tooLarge) {
				Error(w, http.StatusRequestEntityTooLarge, fmt.Sprintf("A request to a plugin is limited to %d bytes", maxProxyBody))
				return
			}
			Error(w, http.StatusBadGateway, fmt.Sprintf("The plugin %q is unavailable", name))
		},
	}
	proxy.ServeHTTP(w, r)
}
