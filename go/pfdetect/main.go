package main

import (
	"bufio"
	"bytes"
	"fmt"
	"github.com/inverse-inc/packetfence/go/detect/parser"
	"github.com/inverse-inc/packetfence/go/log"
	_ "github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"os"
	"os/signal"
	"sync"
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
	err := r.WatchLog()
	if err != nil {
		fmt.Printf("%s\n", err)
	}
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
	fmt.Printf("Stopping runner %s\n", r.PipePath)
	r.File.Close()
	r.StopChan <- struct{}{}
}

type Server struct {
	Runners         []*ParseRunner
	SignalChan      chan os.Signal
	WaitGroup       *sync.WaitGroup
	OnceSignalSetup *sync.Once
	Count           int
}

func (s *Server) AddWait(n int) {
	s.Count += n
	s.WaitGroup.Add(n)
}

func (s *Server) Wait() {
	s.WaitGroup.Wait()
}

func (s *Server) Done() {
	s.Count--
	s.WaitGroup.Done()
}

func NewServer() *Server {
	return &Server{
		SignalChan:      make(chan os.Signal, 1),
		WaitGroup:       &sync.WaitGroup{},
		OnceSignalSetup: &sync.Once{},
	}
}

func (s *Server) AddRunner(runner *ParseRunner) {
	s.Runners = append(s.Runners, runner)
}

func (s *Server) StopRunners() {
	fmt.Printf("Stopping runners\n")
	for _, runner := range s.Runners {
		runner.Stop()
	}
	s.Runners = s.Runners[0:0]
}

func (s *Server) ReloadConfig() {
}

func (s *Server) SetupSignals() {
	s.OnceSignalSetup.Do(func() {
		signal.Notify(s.SignalChan, syscall.SIGTERM, syscall.SIGINT, syscall.SIGHUP)
		wg := &sync.WaitGroup{}
		wg.Add(1)
		s.AddWait(1)
		go func() {
			wg.Done()
			for {
				sig := <-s.SignalChan
				if sig != syscall.SIGHUP {
					s.Done()
					fmt.Printf("Got signal %d\n", sig)
					break
				}
				s.ReloadConfig()
			}
			s.StopRunners()
		}()
		wg.Wait()
		fmt.Printf("Done signal setup\n")
	})
}

func (s *Server) RunRunners() {
	for _, runner := range s.Runners {
		s.AddWait(1)
		go func() {
			defer s.Done()
			runner.Run()
		}()
	}
	fmt.Printf("Ran runners %d\n", s.Count-1)
}

func (s *Server) Run() int {
	s.SetupSignals()
	s.RunRunners()
	s.Wait()
	return 0
}

func main() {
	log.SetProcessName("pfdetect")
	server := NewServer()
	runner, err := NewParseRunner("snort", "/usr/local/pf/logs/pfdetect.log", nil)
	if err != err {
		fmt.Print(err)
	} else {
		server.AddRunner(runner)
	}

	os.Exit(server.Run())
}

func (r *ParseRunner) WatchLog() error {
	detectParser := r.Parser
	reader := bufio.NewReader(r.File)
	buff := bytes.Buffer{}
	var err error

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
				break LOOP
			}

			buff.Write(line)
			if isPrefix == false {
				data := buff.String()
				fmt.Printf("%s\n", data)
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
	fmt.Printf("Stopping reading %s\n", r.PipePath)

	return err
}
