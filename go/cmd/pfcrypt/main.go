package main

import (
	"fmt"
	"os"

	"github.com/inverse-inc/packetfence/go/pfcrypt"
)

func main() {
	if len(os.Args) != 3 {
		panic("Not enough arg")
	}

	switch os.Args[1] {
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
