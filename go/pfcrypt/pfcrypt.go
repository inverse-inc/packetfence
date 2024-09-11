package pfcrypt

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"io"
	"strings"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"golang.org/x/crypto/pbkdf2"
)

const (
	ITERATION_COUNT = 5000
	LEN             = 32
)

type part struct {
	name string
	data []byte
}

func encodeParts(inputs ...part) string {
	parts := make([]string, len(inputs))
	for i, t := range inputs {
		parts[i] = t.name + ":" + base64.StdEncoding.EncodeToString(t.data)
	}

	return strings.Join(parts, ",")
}

func PfEncrypt(data []byte) (string, error) {
	key := derivedKey()
	aesCypher, err := aes.NewCipher(key)
	ad := []byte{}
	if err != nil {
		return "", fmt.Errorf("PfEncrypt NewCipher: %w", err)
	}

	gcm, err := cipher.NewGCM(aesCypher)
	if err != nil {
		return "", fmt.Errorf("PfEncrypt NewGCM: %w", err)
	}

	iv := make([]byte, gcm.NonceSize())
	_, err = io.ReadFull(rand.Reader, iv)
	if err != nil {
		return "", fmt.Errorf("PfEncrypt nonce: %w", err)
	}

	ciphertext := gcm.Seal(nil, iv, data, ad)
	tagOffset := len(ciphertext) - 16
	tag := ciphertext[tagOffset:]
	out := ciphertext[:tagOffset]
	return "PF_ENC[" +
		encodeParts(
			part{name: "data", data: out},
			part{name: "iv", data: iv},
			part{name: "tag", data: tag},
			part{name: "ad", data: ad},
		) +
		"]", nil
}

func decodeParts(input string) ([]part, error) {
	after, found := strings.CutPrefix(input, "PF_ENC[")
	if !found {
		return nil, fmt.Errorf("Invalid format Prefix not found")
	}

	data, found := strings.CutSuffix(after, "]")
	if !found {
		return nil, fmt.Errorf("Invalid format Suffix not found")
	}

	parts := make([]part, 0, 4)

	for _, s := range strings.Split(data, ",") {
		s = strings.TrimSpace(s)
		k, v, found := strings.Cut(s, ":")
		if !found {
			return nil, fmt.Errorf("Invalid format invalid part")
		}

		d, err := base64.StdEncoding.DecodeString(v)
		if err != nil {
			return nil, fmt.Errorf("Cannot decode value: %w", err)
		}

		parts = append(parts, part{name: k, data: d})
	}

	return parts, nil
}

func getPart(parts []part, name string) (part, bool) {
	for _, p := range parts {
		if p.name == name {
			return p, true
		}
	}

	return part{}, false
}

func PfDecrypt(data string) ([]byte, error) {
	parts, err := decodeParts(data)
	if err != nil {
		return nil, err
	}

	tagPart, found := getPart(parts, "tag")
	if !found {
		return nil, fmt.Errorf("Tag Not Found")
	}

	ivPart, found := getPart(parts, "iv")
	if !found {
		return nil, fmt.Errorf("IV Not Found")
	}

	dataPart, found := getPart(parts, "data")
	if !found {
		return nil, fmt.Errorf("Data Not Found")
	}

	adPart, found := getPart(parts, "ad")
	if !found {
		return nil, fmt.Errorf("Associated Data Not Found")
	}

	key := derivedKey()
	aesCypher, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("PfDerypt NewCipher: %w", err)
	}

	gcm, err := cipher.NewGCM(aesCypher)
	if err != nil {
		return nil, fmt.Errorf("PfDerypt NewGCM: %w", err)
	}

	ciphertext := make([]byte, len(tagPart.data)+len(dataPart.data))
	copy(ciphertext, dataPart.data)
	copy(ciphertext[len(dataPart.data):], tagPart.data)
	output, err := gcm.Open(nil, ivPart.data, ciphertext, adPart.data)
	if err != nil {
		return nil, fmt.Errorf("PfDerypt GCM.Open: %w", err)
	}

	return output, nil
}

var systemUser pfconfigdriver.UnifiedApiSystemUser

func derivedKey() []byte {
	return pbkdf2.Key([]byte(systemUser.Pass), []byte("packetfence"), ITERATION_COUNT, LEN, sha256.New)
}

func init() {
	pfconfigdriver.FetchDecodeSocket(context.Background(), &systemUser)
}
