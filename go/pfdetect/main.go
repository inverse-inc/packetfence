package main

import (
	"bufio"
	"bytes"
	"fmt"
	"github.com/inverse-inc/packetfence/go/detect/parser"
	_ "github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"io"
	"os"
	"syscall"
)

func main() {
	err := ParsePipe("/usr/local/pf/logs/pfdetect.log", parser.NewSnortParser())
	fmt.Print(err)

}

func ParsePipe(pipe string, detectParser parser.Parser) error {
	file, err := os.OpenFile(pipe, syscall.O_RDONLY|syscall.O_NONBLOCK, 0600)
	if err != nil {
		return err
	}

	return WatchLog(file, detectParser)
}

func WatchLog(file *os.File, detectParser parser.Parser) error {
	reader := bufio.NewReader(file)
	buff := bytes.Buffer{}
	for {
		line, isPrefix, err := reader.ReadLine()
		if err != nil {
			if err == io.EOF {
				break
			}
			return err
		}

		buff.Write(line)
		if isPrefix == false {
			data := buff.String()
			fmt.Println(data)
			buff.Reset()
			calls, perr := detectParser.Parse(data)
			if perr != nil {
				// Log
				continue
			}

			for _, call := range calls {
				go func(c parser.ApiCall) {
					c.Call()
				}(call)
			}
		}
	}

	return nil
}
