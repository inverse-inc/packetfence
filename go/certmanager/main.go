package main

import (
	"context"
	"sync"
	"syscall"
	"time"

	"github.com/davecgh/go-spew/spew"
	"github.com/hanwen/go-fuse/v2/fs"
	"github.com/hanwen/go-fuse/v2/fuse"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

type CertStore struct {
	fs.Inode
	refreshLauncher *sync.Once
	eap             pfconfigdriver.EAPConfiguration
}

func (r *CertStore) OnAdd(ctx context.Context) {

	for eapkey, _ := range r.eap.Element {
		spew.Dump(eapkey)
		for tlskey, _ := range r.eap.Element[eapkey].TLS {
			var cert []byte
			var key []byte
			var ca []byte
			var bundle []byte
			if r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.CertType == "radius" {
				cert = append(cert, []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Cert)...)
				cert = append(cert, []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Intermediate)...)
				key = append(key, []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Key)...)
				ca = append(ca, []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Ca)...)

				certfile := r.NewPersistentInode(
					ctx, &fs.MemRegularFile{
						Data: cert,
						Attr: fuse.Attr{
							Mode: 0644,
						},
					}, fs.StableAttr{Ino: 2})
				r.AddChild(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.CertType+"_"+eapkey+"_"+tlskey+".crt", certfile, false)

				keyfile := r.NewPersistentInode(
					ctx, &fs.MemRegularFile{
						Data: cert,
						Attr: fuse.Attr{
							Mode: 0644,
						},
					}, fs.StableAttr{Ino: 2})
				r.AddChild(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.CertType+"_"+eapkey+"_"+tlskey+".key", keyfile, false)

				cafile := r.NewPersistentInode(
					ctx, &fs.MemRegularFile{
						Data: cert,
						Attr: fuse.Attr{
							Mode: 0644,
						},
					}, fs.StableAttr{Ino: 2})
				r.AddChild(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.CertType+"_"+eapkey+"_"+tlskey+".pem", cafile, false)

			} else if r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.CertType == "http" {
				bundle = append(cert, []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Cert)...)
				bundle = append(cert, []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Intermediate)...)
				bundle = append(key, []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Key)...)
				bundlefile := r.NewPersistentInode(
					ctx, &fs.MemRegularFile{
						Data: bundle,
						Attr: fuse.Attr{
							Mode: 0644,
						},
					}, fs.StableAttr{Ino: 2})
				r.AddChild(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.CertType+"_"+eapkey+"_"+tlskey+".pem", bundlefile, false)
			}

		}
	}
}

func (r *CertStore) Getattr(ctx context.Context, fh fs.FileHandle, out *fuse.AttrOut) syscall.Errno {
	out.Mode = 0755
	return 0
}

var _ = (fs.NodeGetattrer)((*CertStore)(nil))
var _ = (fs.NodeOnAdder)((*CertStore)(nil))

var ctx = context.Background()

func main() {
	log.SetProcessName("Certmanager")
	ctx = log.LoggerNewContext(ctx)

	mountpoint := "/usr/local/pf/conf/certmanager"

	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.EAPConfiguration)
	configEAP := pfconfigdriver.Config.EAPConfiguration

	spew.Dump(configEAP)

	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.EAPConfiguration)

	opts := &fs.Options{}

	var certStore = &CertStore{}

	certStore.eap = configEAP

	certStore.refreshLauncher = &sync.Once{}

	pfconfigdriver.PfconfigPool.AddRefreshable(ctx, certStore)
	server, err := fs.Mount(mountpoint, certStore, opts)
	if err != nil {
		log.LoggerWContext(ctx).Error("Mount fail: %v\n", err)
	}
	server.Wait()
}

func (r *CertStore) RefreshPfconfig(ctx context.Context) {
	id, err := pfconfigdriver.PfconfigPool.ReadLock(ctx)
	if err == nil {
		defer pfconfigdriver.PfconfigPool.ReadUnlock(ctx, id)

		// We launch the refresh job once, the first time a request comes in
		// This ensures that the pool will run with a context that represents a request (log level for instance)
		r.refreshLauncher.Do(func() {
			ctx := ctx
			go func(ctx context.Context) {
				for {
					pfconfigdriver.PfconfigPool.Refresh(ctx)
					time.Sleep(1 * time.Second)
				}
			}(ctx)
		})
	} else {
		panic("Unable to obtain pfconfigpool lock in certmanager")
	}
}

func (r *CertStore) Refresh(ctx context.Context) {
	// If some of the EAP configuration were changed, we should reload
	if !pfconfigdriver.IsValid(ctx, &pfconfigdriver.Config.EAPConfiguration) {
		log.LoggerWContext(ctx).Info("Reloading EAP configuration and flushing cache")
	}
}
