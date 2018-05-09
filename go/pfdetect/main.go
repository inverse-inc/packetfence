package main

import (
	"bufio"
	"bytes"
	"fmt"
	"github.com/davecgh/go-spew/spew"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/detect/parser"
	_ "github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"log"
	"os"
	"syscall"
)

type RunnerConfig struct {
	DetectType string
}

type ParseRunner struct {
	PipePath string
	File     *os.File
	Parser   parser.Parser
	StopChan chan struct{}
}

func (r *ParseRunner) Run() {
	r.WatchLog()
	r.File.Close()
}

func NewParseRunner(parserType, path string, config interface{}) (*ParseRunner, error) {
	p, err := parser.CreateParser(parserType, config)
	if err != nil {
		return nil, err
	}

	file, err := os.OpenFile(path, syscall.O_RDONLY|syscall.O_NONBLOCK, 0600)
	if err != nil {
		return nil, err
	}

	return &ParseRunner{
		PipePath: path,
		File:     file,
		Parser:   p,
		StopChan: make(chan struct{}),
	}, nil
}

func (r *ParseRunner) Stop() {
	r.StopChan <- struct{}{}
}

func old_main() {
	p, err := NewParseRunner("snort", "/usr/local/pf/logs/pfdetect.log", nil)
	if err != err {
		fmt.Print(err)
	} else {
		p.Run()
	}
}

func main() {
	caddy.AppName = "Sprocketplus"
	caddy.AppVersion = "1.2.3"

	// load caddyfile
	caddyfile, err := caddy.LoadCaddyfile("pfdetect")
	if err != nil {
		log.Fatal(err)
	}
	// start caddy server
	instance, err := caddy.Start(caddyfile)
	if err != nil {
		log.Fatal(err)
	}
	spew.Printf("%#v\n", instance)

	instance.Wait()
}

func (r *ParseRunner) WatchLog() error {
	detectParser := r.Parser
	reader := bufio.NewReader(r.File)
	buff := bytes.Buffer{}
	var err error = nil
	for {
		select {
		case <-r.StopChan:
			break
		default:
			var line []byte
			var isPrefix bool
			line, isPrefix, err = reader.ReadLine()
			if err != nil {
				break
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
	}
	return err
}
