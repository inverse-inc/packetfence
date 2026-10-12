package acme

import (
	"bytes"
	"crypto/sha256"
	"encoding/asn1"
	"testing"
)

// The freshness code is read raw (as Apple sends it) or from an ASN.1
// wrapping; a raw digest that happens to look like DER stays raw.
func TestUnwrapAppleNonce(t *testing.T) {
	digest := sha256.Sum256([]byte("token"))
	bare, _ := asn1.Marshal(digest[:])
	seq, _ := asn1.Marshal(struct {
		Nonce []byte `asn1:"tag:4"`
	}{digest[:]})
	// 0x04 0x1e…: a bare OCTET STRING of 30 bytes if read as DER.
	derLooking := append([]byte{0x04, 0x1e}, digest[:30]...)
	for name, tc := range map[string]struct {
		raw, want []byte
	}{
		"raw":         {digest[:], digest[:]},
		"bare":        {bare, digest[:]},
		"sequence":    {seq, digest[:]},
		"der-looking": {derLooking, derLooking},
	} {
		got, err := unwrapAppleNonce(tc.raw)
		if err != nil || !bytes.Equal(got, tc.want) {
			t.Errorf("%s: got %x, %v; want %x", name, got, err, tc.want)
		}
	}
	if _, err := unwrapAppleNonce([]byte{1, 2, 3}); err == nil {
		t.Errorf("garbage accepted")
	}
}
