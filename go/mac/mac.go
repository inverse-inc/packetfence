package mac

import (
	"errors"
)

type Mac [6]byte

var Zero = Mac{0, 0, 0, 0, 0, 0}

const hexDigit = "0123456789abcdef"
const digits2 = "101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899"
const digits3 = "100101102103104105106107108109110111112113114115116117118119120121122123124125126127128129130131132133134135136137138139140141142143144145146147148149150151152153154155156157158159160161162163164165166167168169170171172173174175176177178179180181182183184185186187188189190191192193194195196197198199200201202203204205206207208209210211212213214215216217218219220221222223224225226227228229230231232233234235236237238239240241242243244245246247248249250251252253254255"

var ErrInvalidFormat = errors.New("Invalid Format")
var ErrNotEnoughBytes = errors.New("Not enough bytes")

func (m *Mac) String() string {
	return string([]byte{
		hexDigit[m[0]>>4],
		hexDigit[m[0]&0xF],
		':',
		hexDigit[m[1]>>4],
		hexDigit[m[1]&0xF],
		':',
		hexDigit[m[2]>>4],
		hexDigit[m[2]&0xF],
		':',
		hexDigit[m[3]>>4],
		hexDigit[m[3]&0xF],
		':',
		hexDigit[m[4]>>4],
		hexDigit[m[4]&0xF],
		':',
		hexDigit[m[5]>>4],
		hexDigit[m[5]&0xF],
	})
}

func (m *Mac) IsZero() bool {
	return *m == Zero
}

func (m *Mac) Decimal() string {
	var _buff [24]byte
	buff := _buff[:0]
	switch {
	case m[0] > 99:
		j := int(m[0]-100) * 3
		buff = append(buff, digits3[j:j+3]...)
	case m[0] > 9:
		j := (m[0] - 10) * 2
		buff = append(buff, digits2[j:j+2]...)
	default:
		buff = append(buff, m[0]+'0')
	}

	for i := 1; i < 6; i++ {
		buff = append(buff, '.')
		switch {
		case m[i] > 99:
			j := int(m[i]-100) * 3
			buff = append(buff, digits3[j:j+3]...)
		case m[i] > 9:
			j := (m[i] - 10) * 2
			buff = append(buff, digits2[j:j+2]...)
		default:
			buff = append(buff, m[i]+'0')
		}
	}

	return string(buff)
}

func hex4tob(h byte) byte {
	switch {
	default:
		return 255
	case '0' <= h && h <= '9':
		return h - '0'
	case 'a' <= h && h <= 'f':
		return h - 'a' + 10
	case 'A' <= h && h <= 'F':
		return h - 'A' + 10
	}
}

func hextob(h []byte) (byte, bool) {
	a := hex4tob(h[0])
	if a == 255 {
		return 0, false
	}

	b := hex4tob(h[1])
	if b == 255 {
		return 0, false
	}

	return (a << 4) | b, true
}

func isSep(c byte) bool {
	return c == ':' || c == '-' || c == '.'
}

func (mac *Mac) InitFromString(s string) error {
	m := Mac{}
	length := len(s)
	if length < 12 {
		return ErrNotEnoughBytes
	}

	switch {
	case length >= 17 && isSep(s[2]):
		// xx:xx:xx:xx:xx:xx, xx-xx-xx-xx-xx-xx, xx.xx.xx.xx.xx.xx
		for i, x := 0, 0; i < 17; i += 3 {
			var ok bool
			if m[x], ok = hextob([]byte(s[i : i+2])); !ok {
				goto error
			}
			x++
		}
	case length >= 15 && isSep(s[3]):
		// 012.345.678.9ab
		// xxx.xxx.xxx.xxx
		var temp [2]byte
		for i, x := 0, 0; i < 15; i += 8 {
			var ok bool
			if m[x], ok = hextob([]byte(s[i : i+2])); !ok {
				goto error
			}
			temp[0], temp[1] = s[i+2], s[i+4]
			if m[x+1], ok = hextob([]byte(temp[:])); !ok {
				goto error
			}
			if m[x+2], ok = hextob([]byte(s[i+5 : i+7])); !ok {
				goto error
			}
			x += 3
		}
	case length >= 14 && isSep(s[4]):
		// 0123.4567.89ab
		// xxxx.xxxx.xxxx
		for i, x := 0, 0; i < 14; i += 5 {
			var ok bool
			if m[x], ok = hextob([]byte(s[i : i+2])); !ok {
				goto error
			}
			if m[x+1], ok = hextob([]byte(s[i+2 : i+4])); !ok {
				goto error
			}
			x += 2
		}
	default:
		// xxxxxxxxxxxx
		for i, x := 0, 0; i < 12; i += 2 {
			var ok bool
			if m[x], ok = hextob([]byte(s[i : i+2])); !ok {
				goto error
			}
			x++
		}
	}

	*mac = m
	return nil

error:
	return ErrInvalidFormat
}

func (m Mac) NodeId(tenant_id uint16) uint64 {
	return (uint64(tenant_id) << 48) | (uint64(m[0]) << 40) | (uint64(m[1]) << 32) | (uint64(m[2]) << 24) | (uint64(m[3]) << 16) | (uint64(m[4]) << 8) | uint64(m[5])
}

// NewFromString parses string
func NewFromString(s string) (Mac, error) {
	m := Mac{}
	if err := m.InitFromString(s); err != nil {
		return Zero, err
	}

	return m, nil
}

// NewFromBytes from Mac
func NewFromBytes(b ...byte) (Mac, error) {
	if len(b) < 6 {
		return Zero, ErrNotEnoughBytes
	}

	return Mac{b[0], b[1], b[2], b[3], b[4], b[5]}, nil
}
