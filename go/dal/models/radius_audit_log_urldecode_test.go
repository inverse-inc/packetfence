package models

import "testing"

func TestRadiusAuditLogUrldecode(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want string
	}{
		{"plain", `User-Name = "bob"`, `User-Name = "bob"`},
		{"flush job format", `User-Name = "host=2Fpc=2Bx",=0AUser-Password = "=3D"`, "User-Name = \"host/pc+x\",\nUser-Password = \"=\""},
		{"raw = in an old CoA row", `Cisco-AVPair =3D subscriber:command=reauthenticate =22=2C NAS-IP-Address =3D 10.0.0.1`, `Cisco-AVPair = subscriber:command=reauthenticate ", NAS-IP-Address = 10.0.0.1`},
		{"trailing =", `a =3D b=`, `a = b=`},
		{"lowercase hex", `=2f`, `/`},
		{"not hex", `=ZZ`, `=ZZ`},
		{"plus is not a space", `a+b`, `a+b`},
	}
	for _, tt := range tests {
		if got := urldecode(tt.in); got != tt.want {
			t.Errorf("%s: urldecode(%q) = %q, want %q", tt.name, tt.in, got, tt.want)
		}
	}
}
