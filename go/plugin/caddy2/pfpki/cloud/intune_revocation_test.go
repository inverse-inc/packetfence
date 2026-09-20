package cloud

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// intuneMock stands in for the PkiConnectorFEService endpoint and
// records what pfpki sent, so the tests can pin the wire format to
// Microsoft's reference client field by field.
type intuneMock struct {
	srv            *httptest.Server
	downloadBody   map[string]any
	downloadHeader http.Header
	uploadBody     map[string]any
	uploadHits     int
	downloadReply  string
	uploadReply    string
}

func newIntuneMock(t *testing.T, downloadReply, uploadReply string) *intuneMock {
	t.Helper()
	m := &intuneMock{downloadReply: downloadReply, uploadReply: uploadReply}
	m.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/" + REVOCATION_DOWNLOAD_URL:
			m.downloadHeader = r.Header.Clone()
			_ = json.Unmarshal(body, &m.downloadBody)
			_, _ = w.Write([]byte(m.downloadReply))
		case "/" + REVOCATION_UPLOAD_URL:
			m.uploadHits++
			_ = json.Unmarshal(body, &m.uploadBody)
			_, _ = w.Write([]byte(m.uploadReply))
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(m.srv.Close)
	return m
}

func (m *intuneMock) client() *Intune {
	return &Intune{
		Client:             m.srv.Client(),
		AccessToken:        "Bearer test-token",
		TransactionID:      "txn-1",
		RevocationEndpoint: &APIEndPoint{Uri: m.srv.URL, ServiceName: REVOCATION_SERVICE_NAME},
	}
}

const twoItems = `{"value":[
  {"requestContext":"ctx-1","serialNumber":"123456789","issuerName":"PF CA","caConfiguration":"cfg"},
  {"requestContext":"ctx-2","serialNumber":"1A2F","issuerName":"PF CA","caConfiguration":""}
]}`

func TestIntuneProcessRevocations_WireFormat(t *testing.T) {
	m := newIntuneMock(t, twoItems, `{"value":true}`)
	cl := m.client()

	var seen []RevocationRequest
	n, err := cl.ProcessRevocations(context.Background(), "PF CA", func(_ context.Context, req RevocationRequest) RevocationResult {
		seen = append(seen, req)
		if req.SerialNumber == "1A2F" {
			return RevocationResult{RequestID: req.RequestID, Succeeded: false,
				ErrorCode: CARequestErrorCertificateNotFound, ErrorMessage: "not ours"}
		}
		return RevocationResult{RequestID: req.RequestID, Succeeded: true}
	})
	if err != nil || n != 2 {
		t.Fatalf("n=%d err=%v", n, err)
	}

	// Headers per IntuneClient.PostRequest + IntuneRevocationClient.
	h := m.downloadHeader
	for k, want := range map[string]string{
		"Authorization":     "Bearer test-token",
		"Content-Type":      "application/json",
		"api-version":       REVOCATION_API_VERSION,
		"client-request-id": "txn-1",
		"UserAgent":         PROVIDER_NAME_AND_VERSION_NAME,
	} {
		if got := h.Get(k); got != want {
			t.Errorf("header %s = %q, want %q", k, got, want)
		}
	}
	if h.Get("api-version") == serviceVersion {
		t.Errorf("revocation calls must not use the SCEP validation api-version")
	}

	// Download body: {"downloadParameters":{"maxRequests":N,"issuerName":"..."}}
	dp, _ := m.downloadBody["downloadParameters"].(map[string]any)
	if dp == nil {
		t.Fatalf("download body missing downloadParameters: %v", m.downloadBody)
	}
	if dp["maxRequests"] != float64(REVOCATION_MAX_PER_CALL) || dp["issuerName"] != "PF CA" {
		t.Errorf("downloadParameters = %v", dp)
	}
	for _, stale := range []string{"certificateProviderName", "transactionId", "callerInfo"} {
		if _, ok := m.downloadBody[stale]; ok {
			t.Errorf("download body carries non-reference field %q", stale)
		}
	}

	// Items reach the callback with every field.
	if len(seen) != 2 || seen[0].RequestID != "ctx-1" || seen[0].SerialNumber != "123456789" ||
		seen[0].IssuerName != "PF CA" || seen[0].CAConfiguration != "cfg" || seen[1].SerialNumber != "1A2F" {
		t.Fatalf("callback saw %+v", seen)
	}

	// Upload body: {"results":[{requestContext,succeeded,errorCode,errorMessage}]}
	results, _ := m.uploadBody["results"].([]any)
	if len(results) != 2 {
		t.Fatalf("upload body = %v", m.uploadBody)
	}
	r0, _ := results[0].(map[string]any)
	r1, _ := results[1].(map[string]any)
	if r0["requestContext"] != "ctx-1" || r0["succeeded"] != true || r0["errorCode"] != CARequestErrorNone {
		t.Errorf("result[0] = %v", r0)
	}
	if _, ok := r0["errorMessage"]; ok {
		t.Errorf("success result must not carry errorMessage: %v", r0)
	}
	if r1["requestContext"] != "ctx-2" || r1["succeeded"] != false ||
		r1["errorCode"] != CARequestErrorCertificateNotFound || r1["errorMessage"] != "not ours" {
		t.Errorf("result[1] = %v", r1)
	}
	for _, k := range []string{"transactionId", "issuerName", "callerInfo"} {
		if _, ok := m.uploadBody[k]; ok {
			t.Errorf("upload body carries non-reference field %q", k)
		}
	}
}

// A failure reported with the None code (or no code) would make Intune
// reject the whole batch; it is normalised to a retryable error.
func TestIntuneProcessRevocations_NormalisesErrorCode(t *testing.T) {
	m := newIntuneMock(t, twoItems, `{"value":true}`)
	_, err := m.client().ProcessRevocations(context.Background(), "PF CA", func(_ context.Context, req RevocationRequest) RevocationResult {
		return RevocationResult{RequestID: req.RequestID, Succeeded: false}
	})
	if err != nil {
		t.Fatal(err)
	}
	results, _ := m.uploadBody["results"].([]any)
	for _, r := range results {
		if r.(map[string]any)["errorCode"] != CARequestErrorRetryable {
			t.Errorf("result = %v", r)
		}
	}
}

func TestIntuneProcessRevocations_UploadNotAccepted(t *testing.T) {
	m := newIntuneMock(t, twoItems, `{"value":false}`)
	n, err := m.client().ProcessRevocations(context.Background(), "PF CA", func(_ context.Context, req RevocationRequest) RevocationResult {
		return RevocationResult{RequestID: req.RequestID, Succeeded: true}
	})
	if err == nil || !strings.Contains(err.Error(), "not accepted") {
		t.Fatalf("expected upload rejection, got n=%d err=%v", n, err)
	}
	if n != 2 {
		t.Fatalf("local progress must still be reported: n=%d", n)
	}
}

func TestIntuneProcessRevocations_EmptyQueue(t *testing.T) {
	m := newIntuneMock(t, `{"value":[]}`, `{"value":true}`)
	n, err := m.client().ProcessRevocations(context.Background(), "", func(_ context.Context, req RevocationRequest) RevocationResult {
		t.Fatalf("callback must not run on an empty queue")
		return RevocationResult{}
	})
	if err != nil || n != 0 || m.uploadHits != 0 {
		t.Fatalf("n=%d err=%v uploads=%d", n, err, m.uploadHits)
	}
	// Empty caName → issuerName null (download every issuer).
	dp, _ := m.downloadBody["downloadParameters"].(map[string]any)
	if v, ok := dp["issuerName"]; !ok || v != nil {
		t.Errorf("issuerName should be JSON null, got %v (present=%v)", v, ok)
	}
}

func TestIntuneProcessRevocations_NoEndpoint(t *testing.T) {
	cl := &Intune{}
	if _, err := cl.ProcessRevocations(context.Background(), "PF CA", nil); err == nil ||
		!strings.Contains(err.Error(), REVOCATION_SERVICE_NAME) {
		t.Fatalf("expected discovery error, got %v", err)
	}
}
