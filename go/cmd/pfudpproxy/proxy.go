package main

import (
	"context"
	"fmt"
	"net"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
)

const (
	// MaxUDPPacketSize is the maximum size of a UDP packet we'll handle
	MaxUDPPacketSize = 65535
	// ReadTimeout is the timeout for reading from UDP connections
	ReadTimeout = 100 * time.Millisecond
)

// UDPProxy handles forwarding UDP packets to healthy backends.
type UDPProxy struct {
	config    *ProxyConfig
	lb        *LoadBalancer
	listeners []*net.UDPConn
	mu        sync.RWMutex
	running   bool
	stopChan  chan struct{}
	wg        sync.WaitGroup
}

// NewUDPProxy creates a new UDP proxy.
func NewUDPProxy(config *ProxyConfig, lb *LoadBalancer) *UDPProxy {
	return &UDPProxy{
		config:   config,
		lb:       lb,
		stopChan: make(chan struct{}),
	}
}

// Start begins listening on all configured VIP:port combinations and forwarding packets.
func (p *UDPProxy) Start(ctx context.Context) {
	p.mu.Lock()
	if p.running {
		p.mu.Unlock()
		return
	}
	p.running = true
	p.mu.Unlock()

	log.LoggerWContext(ctx).Info("Starting UDP proxy")

	for _, port := range p.config.Ports {
		p.wg.Add(1)
		go func(port int) {
			defer p.wg.Done()
			p.listenAndForward(ctx, port)
		}(port)
	}
}

// Stop gracefully stops the UDP proxy.
func (p *UDPProxy) Stop(ctx context.Context) {
	p.mu.Lock()
	if !p.running {
		p.mu.Unlock()
		return
	}
	p.running = false
	close(p.stopChan)
	p.mu.Unlock()

	// Close all listeners
	for _, listener := range p.listeners {
		if listener != nil {
			listener.Close()
		}
	}

	// Wait for all goroutines to finish
	done := make(chan struct{})
	go func() {
		p.wg.Wait()
		close(done)
	}()

	select {
	case <-done:
		log.LoggerWContext(ctx).Info("UDP proxy stopped gracefully")
	case <-ctx.Done():
		log.LoggerWContext(ctx).Warn("UDP proxy shutdown timed out")
	}
}

// UpdateConfig updates the proxy configuration.
// If the VIP address changed, listeners will be restarted.
func (p *UDPProxy) UpdateConfig(ctx context.Context, newConfig *ProxyConfig) {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.config.VIPAddress != newConfig.VIPAddress {
		log.LoggerWContext(ctx).Info(fmt.Sprintf("VIP address changed from %s to %s",
			p.config.VIPAddress, newConfig.VIPAddress))
		// VIP change would require restarting listeners
		// For now, just update the config and log a warning
		log.LoggerWContext(ctx).Warn("VIP address change detected - service restart recommended")
	}

	p.config = newConfig
}

// listenAndForward listens on VIP:port and forwards packets to healthy backends.
func (p *UDPProxy) listenAndForward(ctx context.Context, port int) {
	addr := fmt.Sprintf("%s:%d", p.config.VIPAddress, port)

	udpAddr, err := net.ResolveUDPAddr("udp", addr)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Failed to resolve UDP address %s: %s", addr, err.Error()))
		return
	}

	conn, err := net.ListenUDP("udp", udpAddr)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Failed to listen on %s: %s", addr, err.Error()))
		return
	}

	p.mu.Lock()
	p.listeners = append(p.listeners, conn)
	p.mu.Unlock()

	log.LoggerWContext(ctx).Info(fmt.Sprintf("Listening on %s", addr))

	buf := make([]byte, MaxUDPPacketSize)

	for {
		select {
		case <-p.stopChan:
			return
		case <-ctx.Done():
			return
		default:
			// Set read deadline to allow periodic checking of stop signal
			conn.SetReadDeadline(time.Now().Add(ReadTimeout))

			n, srcAddr, err := conn.ReadFromUDP(buf)
			if err != nil {
				if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
					// Timeout is expected, continue to check stop signal
					continue
				}
				// Check if we're shutting down
				select {
				case <-p.stopChan:
					return
				case <-ctx.Done():
					return
				default:
					log.LoggerWContext(ctx).Error(fmt.Sprintf("Error reading from %s: %s", addr, err.Error()))
					continue
				}
			}

			log.LoggerWContext(ctx).Debug(fmt.Sprintf("Received %d bytes from %s on %s", n, srcAddr.String(), addr))

			// Forward the packet to the primary healthy backend
			p.forwardPacket(ctx, buf[:n], srcAddr, port)
		}
	}
}

// forwardPacket forwards a UDP packet to the primary healthy backend.
func (p *UDPProxy) forwardPacket(ctx context.Context, data []byte, srcAddr *net.UDPAddr, port int) {
	backend := p.lb.GetPrimary()
	if backend == nil {
		log.LoggerWContext(ctx).Warn("No healthy backend available, dropping packet")
		return
	}

	// Create destination address using backend's management IP and same port
	dstAddr := fmt.Sprintf("%s:%d", backend.ManagementIP, port)
	udpDstAddr, err := net.ResolveUDPAddr("udp", dstAddr)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Failed to resolve destination address %s: %s",
			dstAddr, err.Error()))
		return
	}

	// Create a new UDP connection for forwarding
	// Using a new connection each time since NetFlow/sFlow are fire-and-forget
	conn, err := net.DialUDP("udp", nil, udpDstAddr)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Failed to connect to backend %s: %s",
			dstAddr, err.Error()))
		return
	}
	defer conn.Close()

	_, err = conn.Write(data)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Failed to forward packet to %s: %s",
			dstAddr, err.Error()))
		return
	}

	log.LoggerWContext(ctx).Debug(fmt.Sprintf("Forwarded %d bytes from %s to %s",
		len(data), srcAddr.String(), dstAddr))
}
