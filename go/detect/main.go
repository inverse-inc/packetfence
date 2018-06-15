package main

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"os"
	"os/signal"
	"runtime"
	"sync"
	"syscall"

	"github.com/coreos/go-systemd/daemon"
	"github.com/inverse-inc/packetfence/go/detectparser"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

type RunnerConfig struct {
	DetectType string
}

type ParseRunner struct {
	PipePath string
	File     *os.File
	Parser   detectparser.Parser
	StopChan chan struct{}
}

func (r *ParseRunner) Run() error {
	log.Logger().Info(fmt.Sprintf("Start reading from %s", r.PipePath))
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

	log.Logger().Info(fmt.Sprintf("File %s opened ready for reading", r.PipePath))
	return r.WatchLog()
}

func NewParseRunner(parserType string, config *detectparser.PfdetectConfig) (*ParseRunner, error) {
	p, err := detectparser.CreateParser(parserType, config)
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
	log.Logger().Info(fmt.Sprintf("Stopping runner %s", r.PipePath))
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
	log.Logger().Info(fmt.Sprintf("Done for: %s", msg))
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
	log.Logger().Info("Stopping Detect Parsers")
	for _, runner := range s.Runners {
		runner.Stop()
		s.Done(runner.PipePath)
	}
	s.Runners = s.Runners[0:0]
}

func (s *Server) ReloadConfig() {
	s.StopRunners()
	s.LoadParsersFromConfig()
	s.RunRunners()
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
			s.NotifySystemd("STOPPING=1")
			s.StopRunners()
		}()
		wg.Wait()
		log.Logger().Debug("Done signal setup")
	})
}

func GetPfDetectConfig() []detectparser.PfdetectConfig {
	ctx := context.Background()
	keys, _ := pfconfigdriver.FetchKeys(ctx, "config::Pfdetect")
	configs := make([]detectparser.PfdetectConfig, 0, len(keys))
	for _, n := range keys {
		config := detectparser.PfdetectConfig{Name: n, PfconfigHashNS: n}
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
	log.Logger().Info(fmt.Sprintf("%d parse runners are running", len(s.Runners)))
}

func (s *Server) NotifySystemd(msg string) {
	_, err := daemon.SdNotify(false, msg)
	if err != nil {
		log.Logger().Error(fmt.Sprintf("Error sending systemd ready notification: %s", err.Error()))
	}
}

func (s *Server) Run() int {
	s.SetupSignals()
	s.NotifySystemd("READY=1")
	s.LoadParsersFromConfig()
	s.RunRunners()
	s.Wait()
	return 0
}

func (s *Server) LoadParsersFromConfig() {
	configs := GetPfDetectConfig()
	for _, config := range configs {
		runner, err := NewParseRunner(config.Type, &config)
		if err != nil {
			log.Logger().Error(fmt.Sprintf("Error setting up %s: %s", config.Path, err.Error()))
		} else {
			s.AddRunner(runner)
			log.Logger().Info(fmt.Sprintf("Added %s", runner.PipePath))
		}
	}
}

func main() {
	log.SetProcessName("pfdetect")
	server := NewServer()
	os.Exit(server.Run())
}

func (r *ParseRunner) WatchLog() error {
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
				buff.Reset()
				err = r.ParseLine(data)
				if err != nil {
					log.Logger().Error(fmt.Sprintf("When processing line '%s' for pipe %s : %s", data, r.PipePath, err))
				}
			}
		}
	}

	log.Logger().Info(fmt.Sprintf("Stopping reading %s", r.PipePath))
	return err
}

func (r *ParseRunner) ParseLine(data string) (err error) {
	defer func() {
		if rv := recover(); rv != nil {
			err = fmt.Errorf("Panic while processing %s: %v ", r.PipePath, rv)
		}
	}()

	calls, err := r.Parser.Parse(data)
	if err != nil {
		return err
	}

	for _, call := range calls {
		go func(c detectparser.ApiCall) {
			err := c.Call()
			if err != nil {
				log.Logger().Error(fmt.Sprintf("Error handling API call for %s: %s\n", r.PipePath, err))
			}
		}(call)
	}

	return nil
}
