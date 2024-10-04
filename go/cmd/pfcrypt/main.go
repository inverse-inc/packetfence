package main

import (
	"fmt"
	"os"

	"github.com/inverse-inc/packetfence/go/config/pfcrypt"
)

const usage = `Usage:
	pfcrypt encrypt <text>
	pfcrypt decrypt <ciphertext>
`

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintf(os.Stderr, "Not enough args\n%s\n", usage)
		os.Exit(1)
		return
	}

	switch os.Args[1] {
	default:
		fmt.Fprintf(os.Stderr, "Invalid option\n%s\n", usage)
		os.Exit(1)
		return
	case "encrypt":
		ciphertext, err := pfcrypt.PfEncrypt([]byte(os.Args[2]))
		if err != nil {
			fmt.Printf("Error: %s\n", err.Error())
			os.Exit(1)
			return
		}

		fmt.Println(ciphertext)
	case "decrypt":
		text, err := pfcrypt.PfDecrypt(os.Args[2])
		if err != nil {
			fmt.Printf("Error: %s\n", err.Error())
			os.Exit(1)
			return
		}

		fmt.Println(string(text))
	}
}
