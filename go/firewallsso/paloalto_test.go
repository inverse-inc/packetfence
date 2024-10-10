package firewallsso

import (
	"testing"
)

func TestPaloAltoStartHttpPayload(t *testing.T) {
	pa := PaloAlto{}

	payload := pa.startHttpPayload(ctx, sampleInfo, 86400)

	expected := `
<uid-message>
	<version>1.0</version>
	<type>update</type>
	<payload>
		<login>
			<entry name="lzammit" ip="1.2.3.4" timeout="1440"/>
		</login>
		<register-user>
			<entry user="lzammit">
				<tag>
					<member timeout="86400">default</member>
				</tag>
			</entry>
		</register-user>
	</payload>
</uid-message>
`

	if payload != expected {
		t.Errorf("Unexpected payload was created. %s instead of %s", payload, expected)
	}

}

func TestPaloAltoStopHttpPayload(t *testing.T) {
	pa := PaloAlto{}

	payload := pa.stopHttpPayload(ctx, sampleInfo)

	expected := `
<uid-message>
	<version>1.0</version>
	<type>update</type>
	<payload>
		<logout>
			<entry name="lzammit" ip="1.2.3.4"/>
		</logout>
		<unregister-user>
			<entry user="lzammit">
				<tag>
					<member>default</member>
				</tag>
			</entry>
		</unregister-user>
	</payload>
</uid-message>
`

	if payload != expected {
		t.Errorf("Unexpected payload was created. %s instead of %s", payload, expected)
	}

}
