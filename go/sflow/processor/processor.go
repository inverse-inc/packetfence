package processor

import (
	"errors"
	"github.com/inverse-inc/packetfence/go/bytearraypool"
	"github.com/inverse-inc/packetfence/go/bytesdispatcher"
	"github.com/inverse-inc/packetfence/go/sflow"
	"net"
	"runtime"
	"strings"
)

type SamplesHandler interface {
	HandleSamples(header *sflow.Header, samples []sflow.Sample)
}

type SamplesHandlerFunc func(header *sflow.Header, samples []sflow.Sample)

func (f SamplesHandlerFunc) HandleSamples(header *sflow.Header, samples []sflow.Sample) {
	f(header, samples)
}

type Processor struct {
	// Conn a net.PacketConn.
	// Default : UDPConn listining at 127.0.0.1:6343.
	Conn net.PacketConn
	// Handler a FlowHandler function to handle the netflow5 flows
	// Required.
	Handler SamplesHandler
	// Workers the number of worker to work on the queue
	// Default : The number of runtime.GOMAXPROCS
	Workers int
	// Backlog how many packets are can be queued before being processed
	// Defaults : 100
	Backlog int
	// PacketSize size of packet going to be received
	// Default : 2048
	PacketSize int
	// ByteArrayPoolSize the number byte arrays to have avialable in the pool.
	// Default : The same size of the backlog
	ByteArrayPoolSize int
	byteArrayPool     *bytearraypool.ByteArrayPool
	stopChan          chan struct{}
	dispatcher        *bytesdispatcher.Dispatcher
}

func (p *Processor) setDefaults() {
	if p.Handler == nil {
		panic(errors.New("No handler defined"))
	}

	if p.Workers <= 0 {
		p.Workers = runtime.GOMAXPROCS(0)
	}

	if p.PacketSize <= 0 {
		p.PacketSize = 2048
	}

	if p.Backlog <= 0 {
		p.Backlog = 100
	}

	if p.ByteArrayPoolSize <= 0 {
		p.ByteArrayPoolSize = p.Backlog
	}

	p.byteArrayPool = bytearraypool.NewByteArrayPool(p.ByteArrayPoolSize, p.PacketSize)

	if p.Conn == nil {
		conn, err := net.ListenPacket("udp", "127.0.0.1:6343")
		if err != nil {
			panic(err)
		}

		p.Conn = conn
	}

	if p.stopChan == nil {
		p.stopChan = make(chan struct{}, 1)
	}

	p.dispatcher = bytesdispatcher.NewDispatcher(p.Workers, p.Backlog, bytesHandlerForSamplesHandler(p.Handler), p.byteArrayPool)
}

func bytesHandlerForSamplesHandler(h SamplesHandler) bytesdispatcher.BytesHandler {
	return bytesdispatcher.BytesHandlerFunc(
		func(buffer []byte) {
			head := sflow.Header{}
			next := head.Parse(buffer)
			samples, err := head.ParseSamples(next)
			if err == nil {
				h.HandleSamples(&head, samples)
			}

		},
	)
}

// Stop stops the processor.
func (p *Processor) Stop() {
	c := p.stopChan
	p.stopChan = nil
	c <- struct{}{}
	p.Conn.Close()
}

// StopAndWait stops the processor and wait for the dispatcher to cleanup
func (p *Processor) StopAndWait() {
	p.Stop()
	p.dispatcher.Wait()
}

func (p *Processor) isCloseError(err error) bool {
	if p.stopChan != nil {
		return false
	}

	str := err.Error()
	return strings.Contains(str, "use of closed network connection")
}

// Start starts the processor.
func (p *Processor) Start() {
	p.setDefaults()
	dispatcher := p.dispatcher
	dispatcher.Run()
	stopChan := p.stopChan

LOOP:
	for {
		buffer := p.byteArrayPool.Get()
		rlen, remote, err := p.Conn.ReadFrom(buffer)
		if err != nil {
			if p.isCloseError(err) {
				break
			}

			panic(err)
		}
		_, _ = rlen, remote
		dispatcher.SubmitJob(buffer)
		select {
		case <-stopChan:
			break LOOP
		default:
			continue
		}
	}

	dispatcher.Stop()
}
