package main

import (
    "syscall"
    "os"
    "bytes"
    "bufio"
    "fmt"
    "io"
	_ "github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/detect"
)


func main() {
    err := ParsePipe("/usr/local/pf/logs/pfdetect.log", detect.NewSnortParser())
    fmt.Print(err)

}

func ParsePipe( pipe string, parser detect.Parser) error {
    file, err := os.OpenFile(pipe, syscall.O_RDONLY | syscall.O_NONBLOCK, 0600)
    if err != nil {
        return err
    }

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
            buff.Reset()
            fmt.Println(data)
            var calls []detect.ApiCall
            var perr error
            calls , perr = parser.Parse(data)
            if perr != nil {
                // Log
                continue
            }

            for _, call := range calls {
                go func(c detect.ApiCall) {
                    c.Call()
                }(call)
            }
        }
    }
    return err
}
