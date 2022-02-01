package admin_api_audit_log

import (
	"encoding/json"
)

func MaskSecrets(jsonString string, keys ...string) (string, error) {
	var data map[string]interface{}
	if err := json.Unmarshal([]byte(jsonString), &data); err != nil {
		return "", err
	}
	keysToMask := map[string]struct{}{}

	for _, key := range keys {
		keysToMask[key] = struct{}{}
	}

	maskSecrets(data, keysToMask)

	if out, err := json.Marshal(data); err != nil {
		return "", err
	} else {
		return string(out), nil
	}
}

func maskSecrets(data interface{}, keys map[string]struct{}) {
	switch t := data.(type) {
	case map[string]interface{}:
		for k, _ := range t {
			if _, ok := keys[k]; ok {
				t[k] = "**********"
			}
		}
	case []interface{}:
		for _, v := range t {
			maskSecrets(v, keys)
		}
	default:

	}
}
