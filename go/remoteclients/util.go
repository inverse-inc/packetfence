package remoteclients

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"io"

	"github.com/inverse-inc/packetfence/go/sharedutils"

	"golang.org/x/crypto/curve25519"
)

const keySize = 32

var random = rand.Read

func GeneratePrivateKey() ([32]byte, error) {
	var b [32]byte
	_, err := random(b[:])
	return b, err
}

func GeneratePublicKey(priv [32]byte) ([32]byte, error) {
	var pub [32]byte
	curve25519.ScalarBaseMult(&pub, &priv)
	return pub, nil
}

func SharedSecret(privateKey, publicKey [32]byte) [32]byte {
	var out1 [32]byte
	curve25519.ScalarMult(&out1, &privateKey, &publicKey)
	return out1
}

func BuildP2PKey(key1, key2 string) string {
	if key2 < key1 {
		key1bak := key1
		key1 = key2
		key2 = key1bak
	}

	key1dec, err := base64.StdEncoding.DecodeString(key1)
	sharedutils.CheckError(err)
	key2dec, err := base64.StdEncoding.DecodeString(key2)
	sharedutils.CheckError(err)

	combined := append(key1dec, key2dec...)
	return base64.URLEncoding.EncodeToString(combined)
}

func B64KeyToBytes(key string) ([32]byte, error) {
	b, err := base64.URLEncoding.DecodeString(key)
	var b2 [32]byte
	for i := range b {
		b2[i] = b[i]
	}
	return b2, err
}

func URLB64KeyToBytes(key string) ([32]byte, error) {
	b, err := base64.URLEncoding.DecodeString(key)
	var b2 [32]byte
	for i := range b {
		b2[i] = b[i]
	}
	return b2, err
}

func EncryptMessage(key, text []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	b := base64.URLEncoding.EncodeToString(text)
	ciphertext := make([]byte, aes.BlockSize+len(b))
	iv := ciphertext[:aes.BlockSize]
	if _, err := io.ReadFull(rand.Reader, iv); err != nil {
		return nil, err
	}
	cfb := cipher.NewCFBEncrypter(block, iv)
	cfb.XORKeyStream(ciphertext[aes.BlockSize:], []byte(b))
	return ciphertext, nil
}

func DecryptMessage(key, text []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	if len(text) < aes.BlockSize {
		return nil, errors.New("ciphertext too short")
	}
	iv := text[:aes.BlockSize]
	text = text[aes.BlockSize:]
	cfb := cipher.NewCFBDecrypter(block, iv)
	cfb.XORKeyStream(text, text)
	data, err := base64.URLEncoding.DecodeString(string(text))
	if err != nil {
		return nil, err
	}
	return data, nil
}
