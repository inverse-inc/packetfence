package pfcrypt

import (
	"encoding/json"
	"strings"
)

type CryptString string

func (c CryptString) AsEncrypted() (string, error) {
	if strings.HasPrefix(string(c), PREFIX) {
		return string(c), nil
	}

	return PfEncrypt([]byte(c))
}

func (c CryptString) String() string {
	return string(c)
}

func (c CryptString) MarshalJSON() ([]byte, error) {
	out, err := c.AsEncrypted()
	if err != nil {
		return nil, err
	}

	return json.Marshal(out)
}

func (c *CryptString) UnmarshalJSON(in []byte) error {
	str := ""
	if err := json.Unmarshal(in, &str); err != nil {
		return err
	}

	if !strings.HasPrefix(str, PREFIX) {
		*c = CryptString(str)
		return nil
	}

	out, err := PfDecrypt(str)
	if err != nil {
		return err
	}

	*c = CryptString(string(out))
	return nil
}
