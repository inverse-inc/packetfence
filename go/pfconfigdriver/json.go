package pfconfigdriver

import (
	"encoding/json"
	"strconv"
)

type PfInt int

func (i *PfInt) UnmarshalJSON(b []byte) error {
	switch b[0] {
	case '"':
		var s string
		if err := json.Unmarshal(b, &s); err != nil {
			return err
		}

		val, err := strconv.ParseInt(s, 10, 64)
		if err != nil {
			return err
		}

		*i = PfInt(int(val))
		return nil
	case 'n', 'f':
		*i = PfInt(0)
		return nil
	case 't':
		*i = PfInt(1)
		return nil
	}

	var val int
	if err := json.Unmarshal(b, &val); err != nil {
		return err
	}

	*i = PfInt(val)
	return nil
}

func (i PfInt) MarshalJSON() ([]byte, error) {
	return json.Marshal(int(i))
}
