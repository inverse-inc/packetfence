package main

import (
	"bufio"
	"bytes"
	"fmt"
	"sync"
	//"github.com/davecgh/go-spew/spew"
	"github.com/inverse-inc/packetfence/go/detect/parser"
	_ "github.com/inverse-inc/packetfence/go/pfconfigdriver"
	//"log"
	"os"
	"os/signal"
	"strings"
	"syscall"
)

var ISENABLED = map[string]bool{
	"enabled": true,
	"enable":  true,
	"yes":     true,
	"y":       true,
	"true":    true,
	"1":       true,

	"disabled": false,
	"disable":  false,
	"false":    false,
	"no":       false,
	"n":        false,
	"0":        false,
}

func IsEnabled(enabled string) bool {
	if e, found := ISENABLED[strings.TrimSpace(enabled)]; found {
		return e
	}

	return false
}

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
	r.File.Close()
	r.StopChan <- struct{}{}
}

var runners []*ParseRunner

var wg = &sync.WaitGroup{}

func setupSignals() {
	c := make(chan os.Signal, 1)
	signal.Notify(c, syscall.SIGTERM, syscall.SIGINT)
	wg.Add(1)
	go func() {
		<-c
		wg.Done()
	}()
	for _, runner := range runners {
		runner.Stop()
	}
}

func main() {
	p, err := NewParseRunner("snort", "/usr/local/pf/logs/pfdetect.log", nil)
	if err != err {
		fmt.Print(err)
	} else {
		runners = append(runners, p)
	}

	for _, runner := range runners {
		wg.Add(1)
		go func() {
			defer wg.Done()
			runner.Run()
		}()
	}
	setupSignals()

	wg.Wait()
}

func (r *ParseRunner) WatchLog() error {
	detectParser := r.Parser
	reader := bufio.NewReader(r.File)
	buff := bytes.Buffer{}
	var err error = nil
LOOP:
	for {
		select {
		case <-r.StopChan:
			break LOOP
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
