package main

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"github.com/coreos/go-systemd/daemon"
	"github.com/inverse-inc/packetfence/go/detect/parser"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"os"
	"os/signal"
	"runtime"
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

func (r *ParseRunner) Run() error {
	fmt.Printf("Start reading from %s\n", r.PipePath)
	var err error
	r.File, err = os.OpenFile(r.PipePath, syscall.O_RDWR, 0600)
	if err != nil {
		return err
	}

	select {
	case <-r.StopChan:
		r.File.Close()
		return fmt.Errorf("Runner was stopped before reading from pipe started")
	default:
	}

	fmt.Printf("File %s opened ready for reading\n", r.PipePath)
	return r.WatchLog()
}

func NewParseRunner(parserType string, config *parser.PfdetectConfig) (*ParseRunner, error) {
	p, err := parser.CreateParser(parserType, config)
	if err != nil {
		return nil, err
	}

	return &ParseRunner{
		PipePath: config.Path,
		Parser:   p,
		StopChan: make(chan struct{}, 1),
	}, nil
}

func (r *ParseRunner) Stop() {
	fmt.Printf("Stopping runner %s\n", r.PipePath)
	r.StopChan <- struct{}{}
	r.File.Close()
}

type Server struct {
	Runners         Runners
	SignalChan      chan os.Signal
	WaitGroup       *sync.WaitGroup
	OnceSignalSetup *sync.Once
	CPUCount        int
}

func (s *Server) AddWait(n int) {
	s.WaitGroup.Add(n)
}

func (s *Server) Wait() {
	s.WaitGroup.Wait()
}

func (s *Server) Done(msg string) {
	fmt.Printf("Done for %s\n", msg)
	s.WaitGroup.Done()
}

func NewServer() *Server {
	return &Server{
		SignalChan:      make(chan os.Signal, 1),
		WaitGroup:       &sync.WaitGroup{},
		OnceSignalSetup: &sync.Once{},
		CPUCount:        runtime.NumCPU(),
	}
}

type Runners []*ParseRunner

func (array *Runners) Append(r ...*ParseRunner) {
	*array = append(*array, r...)
}

func (s *Server) AddRunner(runner *ParseRunner) {
	s.Runners.Append(runner)
}

func (s *Server) StopRunners() {
	fmt.Printf("Stopping runners\n")
	for _, runner := range s.Runners {
		fmt.Printf("Stopped %s\n", runner.PipePath)
		runner.Stop()
		s.Done(runner.PipePath)
	}
	s.Runners = s.Runners[0:0]
}

func (s *Server) ReloadConfig() {
	s.StopRunners()
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
					s.Done("Signal")
					break
				}
				s.ReloadConfig()
			}
			s.NotifySystemd(daemon.SdNotifyStopping)
			s.StopRunners()
		}()
		wg.Wait()
		fmt.Printf("Done signal setup\n")
	})
}

func GetPfDetectConfig() []parser.PfdetectConfig {
	ctx := context.TODO()
	keys, _ := pfconfigdriver.FetchKeys(ctx, "config::Pfdetect")
	configs := make([]parser.PfdetectConfig, 0, len(keys))
	for _, n := range keys {
		config := parser.PfdetectConfig{Name: n, PfconfigHashNS: n}
		_, _ = pfconfigdriver.FetchDecodeSocketCache(ctx, &config)
		configs = append(configs, config)
	}
	return configs
}

func (s *Server) RunRunners() {
	for _, runner := range s.Runners {
		s.AddWait(1)
		go func(runner *ParseRunner) {
			runner.Run()
		}(runner)
	}
	fmt.Printf("Ran runners %d\n", len(s.Runners))
}

func (s *Server) NotifySystemd(msg string) {
	_, err := daemon.SdNotify(false, msg)
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error sending systemd ready notification %s", err.Error())
	}
}

func (s *Server) Run() int {
	s.SetupSignals()
	s.NotifySystemd(daemon.SdNotifyReady)
	s.RunRunners()
	s.Wait()
	return 0
}

func main() {
	log.SetProcessName("pfdetect")
	server := NewServer()
	configs := GetPfDetectConfig()
	number_of_procs := runtime.GOMAXPROCS(0)
	number_of_procs += len(configs)
	fmt.Printf("Increasing GOMAXPROCS to %d\n", number_of_procs)
	runtime.GOMAXPROCS(number_of_procs)
	for _, config := range configs {
		runner, err := NewParseRunner(config.Type, &config)
		if err != nil {
			fmt.Print(err)
		} else {
			fmt.Printf("Adding %s\n", runner.PipePath)
			server.AddRunner(runner)
		}
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
			fmt.Printf("Recieved stop on a channel")
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
