package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"os/user"
	"strconv"
	"sync"
	"syscall"
	"time"

	"github.com/coreos/go-systemd/daemon"
	"github.com/hanwen/go-fuse/v2/fs"
	"github.com/hanwen/go-fuse/v2/fuse"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// CertStore truct
type CertStore struct {
	fs.Inode
	refreshLauncher *sync.Once
	eap             pfconfigdriver.EAPConfiguration
	certificates    map[string]map[string]map[string][]byte
	RegularFile     map[string]map[string]map[string]map[string]*MemRegularFile
	Owner           fuse.Owner
}

func main() {

	sigs := make(chan os.Signal, 1)
	done := make(chan bool, 1)

	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)

	log.SetProcessName("Certmanager")
	ctx = log.LoggerNewContext(ctx)

	mountpoint := "/usr/local/pf/conf/certmanager"

	configEAP := pfconfigdriver.Config.EAPConfiguration

	opts := &fs.Options{}

	var certStore = &CertStore{}

	certStore.eap = configEAP

	certStore.refreshLauncher = &sync.Once{}

	User, _ := user.Lookup("pf")
	Uid, _ := strconv.Atoi(User.Uid)
	Gid, _ := strconv.Atoi(User.Gid)

	certStore.Owner = fuse.Owner{Uid: uint32(Uid), Gid: uint32(Gid)}
	opts.GID = certStore.Owner.Gid
	opts.UID = certStore.Owner.Uid

	opts.MountOptions = fuse.MountOptions{AllowOther: true}

	// Read Fresh configuration
	pfconfigdriver.FetchDecodeSocket(ctx, &pfconfigdriver.Config.EAPConfiguration)
	certStore.eap = pfconfigdriver.Config.EAPConfiguration

	certStore.Init(ctx)

	server, err := fs.Mount(mountpoint, certStore, opts)
	if err != nil {
		log.LoggerWContext(ctx).Error("Mount fail: %v\n", err)
	}

	pfconfigdriver.PfconfigPool.AddRefreshable(ctx, certStore)

	go func(server *fuse.Server) {
		sig := <-sigs
		fmt.Println()
		fmt.Println(sig)
		server.Unmount()
		done <- true
		os.Exit(0)
	}(server)

	go func() {
		<-done
	}()

	certStore.RefreshPfconfig(ctx)

	daemon.SdNotify(false, "READY=1")

	go func() {
		interval, err := daemon.SdWatchdogEnabled(false)
		if err != nil || interval == 0 {
			return
		}
		for {
			daemon.SdNotify(false, "WATCHDOG=1")
			time.Sleep(interval / 3)
		}
	}()

	defer NotifySystemd("STOPPING=1")

	server.Wait()
}

// OnAdd Initialize the filesystem
func (r *CertStore) OnAdd(ctx context.Context) {
	RegularFile := make(map[string]map[string]map[string]map[string]*MemRegularFile)
	Inode := uint64(2)

	for eapkey, element := range r.eap.Element {
		RegularFile[eapkey] = make(map[string]map[string]map[string]*MemRegularFile)
		for tlskey := range element.TLS {
			RegularFile[eapkey][tlskey] = make(map[string]map[string]*MemRegularFile)
			certType := "radius"
			RegularFile[eapkey][tlskey][certType] = make(map[string]*MemRegularFile)

			if r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Default == "yes" {

				cert := r.NewPersistentInode(ctx, &fs.MemSymlink{
					Data: r.certificates[eapkey][tlskey]["cert"],
					Attr: fuse.Attr{
						Mode:  0664,
						Owner: r.Owner,
					},
				}, fs.StableAttr{Mode: syscall.S_IFLNK})
				r.AddChild(certType+"_"+eapkey+"_"+tlskey+".crt", cert, false)

				key := r.NewPersistentInode(ctx, &fs.MemSymlink{
					Data: r.certificates[eapkey][tlskey]["key"],
					Attr: fuse.Attr{
						Mode:  0664,
						Owner: r.Owner,
					},
				}, fs.StableAttr{Mode: syscall.S_IFLNK})
				r.AddChild(certType+"_"+eapkey+"_"+tlskey+".key", key, false)

				ca := r.NewPersistentInode(ctx, &fs.MemSymlink{
					Data: r.certificates[eapkey][tlskey]["ca"],
					Attr: fuse.Attr{
						Mode:  0664,
						Owner: r.Owner,
					},
				}, fs.StableAttr{Mode: syscall.S_IFLNK})
				r.AddChild(certType+"_"+eapkey+"_"+tlskey+".pem", ca, false)

			} else {

				RegularFile[eapkey][tlskey][certType]["cert"] = &MemRegularFile{
					Data: r.certificates[eapkey][tlskey]["cert"],
					Attr: fuse.Attr{
						Mode:  0664,
						Owner: r.Owner,
					},
				}

				certfile := r.NewPersistentInode(ctx, RegularFile[eapkey][tlskey][certType]["cert"], fs.StableAttr{Ino: Inode})
				r.AddChild(certType+"_"+eapkey+"_"+tlskey+".crt", certfile, false)

				Inode++
				RegularFile[eapkey][tlskey][certType]["key"] = &MemRegularFile{
					Data: r.certificates[eapkey][tlskey]["key"],
					Attr: fuse.Attr{
						Mode:  0664,
						Owner: r.Owner,
					},
				}
				keyfile := r.NewPersistentInode(ctx, RegularFile[eapkey][tlskey][certType]["key"], fs.StableAttr{Ino: Inode})
				r.AddChild(certType+"_"+eapkey+"_"+tlskey+".key", keyfile, false)
				Inode++

				RegularFile[eapkey][tlskey][certType]["pem"] = &MemRegularFile{
					Data: r.certificates[eapkey][tlskey]["ca"],
					Attr: fuse.Attr{
						Mode:  0664,
						Owner: r.Owner,
					},
				}
				cafile := r.NewPersistentInode(ctx, RegularFile[eapkey][tlskey][certType]["pem"], fs.StableAttr{Ino: Inode})
				r.AddChild(certType+"_"+eapkey+"_"+tlskey+".pem", cafile, false)
				Inode++
			}
		}
	}
	r.RegularFile = RegularFile
}

// Getattr function
func (r *CertStore) Getattr(ctx context.Context, fh fs.FileHandle, out *fuse.AttrOut) syscall.Errno {
	out.Mode = 0755
	return 0
}

var _ = (fs.NodeGetattrer)((*CertStore)(nil))
var _ = (fs.NodeOnAdder)((*CertStore)(nil))

var ctx = context.Background()

// NotifySystemd notify systemd
func NotifySystemd(msg string) {
	_, err := daemon.SdNotify(false, msg)
	if err != nil {
		log.LoggerWContext(context.Background(), fmt.Sprintf("Error sending systemd ready notification: %s", err.Error()))
	}
}

// RefreshPfconfig refresh the pfconfig pool
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
		log.LoggerWContext(context.Background(), "Unable to obtain pfconfigpool lock in certmanager")
	}
}

// Refresh the content of the files if something changed
func (r *CertStore) Refresh(ctx context.Context) {
	// If some of the EAP configuration were changed, we should reload

	if !pfconfigdriver.IsValid(ctx, &pfconfigdriver.Config.EAPConfiguration) {
		log.LoggerWContext(ctx).Info("Reloading EAP configuration and flushing cache")
		r.Init(ctx)
		r.Reload(ctx)
	}
}

// Init initialze the certificates map
func (r *CertStore) Init(ctx context.Context) {
	certificate := make(map[string]map[string]map[string][]byte)
	// Read Fresh configuration
	pfconfigdriver.FetchDecodeSocketCache(ctx, &pfconfigdriver.Config.EAPConfiguration)
	r.eap = pfconfigdriver.Config.EAPConfiguration

	for eapkey := range r.eap.Element {
		certificate[eapkey] = make(map[string]map[string][]byte)
		for tlskey := range r.eap.Element[eapkey].TLS {
			certificate[eapkey][tlskey] = make(map[string][]byte)
			if r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Default == "yes" {
				certificate[eapkey][tlskey]["cert"] = []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Cert)
				certificate[eapkey][tlskey]["key"] = []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Key)
				certificate[eapkey][tlskey]["ca"] = []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Ca)
			} else {
				certificate[eapkey][tlskey]["cert"] = concatAppend([][]byte{[]byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Cert), []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Intermediate)})
				certificate[eapkey][tlskey]["key"] = []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Key)
				certificate[eapkey][tlskey]["ca"] = []byte(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Ca)
			}
		}
	}
	r.certificates = certificate
}

// Reload the content of the files
func (r *CertStore) Reload(ctx context.Context) {
	certType := "radius"
	for eapkey := range r.eap.Element {

		for tlskey := range r.eap.Element[eapkey].TLS {
			if !(r.eap.Element[eapkey].TLS[tlskey].CertificateProfile.Default == "yes") {
				r.RegularFile[eapkey][tlskey][certType]["cert"].SetData(r.certificates[eapkey][tlskey]["cert"])
				r.RegularFile[eapkey][tlskey][certType]["key"].SetData(r.certificates[eapkey][tlskey]["key"])
				r.RegularFile[eapkey][tlskey][certType]["pem"].SetData(r.certificates[eapkey][tlskey]["ca"])
			}
		}
	}

}

func concatAppend(slices [][]byte) []byte {
	var tmp []byte
	for _, s := range slices {
		tmp = append(tmp, s...)
		tmp = append(tmp, byte('\r'))
		tmp = append(tmp, byte('\n'))
	}
	return tmp
}
