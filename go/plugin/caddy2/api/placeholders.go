package api

var placeHolders = map[string]string{
	"Tunnel-Private-Group-Id": "$vlan",
	"Filter-ID":               "$role",
	"Calling-Station-Id":      "${macToEUI48($mac)}",
}
