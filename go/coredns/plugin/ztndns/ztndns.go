// Package ztndns implements a plugin that returns details about the resolving
// querying it.
package ztndns

import (
	"bytes"
	"database/sql"
	"fmt"
	"strings"

	"net"
	"os"
	"regexp"
	"sync"
	"time"

	"github.com/inverse-inc/packetfence/go/coredns/plugin"
	"github.com/inverse-inc/packetfence/go/coredns/request"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/sharedutils"

	//Import mysql driver
	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/miekg/dns"
	"golang.org/x/net/context"
)

type ztndns struct {
	InternalPortalIP net.IP
	RedirectIP       net.IP
	Db               *sql.DB
	DNSAudit         *sql.Stmt // prepared statement for dns_audit_log
	Next             plugin.Handler
	HostIP           map[int]*HostIPMap
	refreshLauncher  *sync.Once
	recordDNS        bool
}

type HostIPMap struct {
	ComputerName *regexp.Regexp
	Ip           net.IP
}

type dbConf struct {
	DBHost     string `json:"host"`
	DBPort     string `json:"port"`
	DBUser     string `json:"user"`
	DBPassword string `json:"pass"`
	DB         string `json:"db"`
}

func (ztn *ztndns) RefreshPfconfig(ctx context.Context) {

	ztn.refreshLauncher.Do(func() {
		ctx := ctx
		go func(ctx context.Context) {
			for {
				err := ztn.HostIPMAP(ctx)
				if err != nil {
					log.LoggerWContext(ctx).Error(err.Error())
				}
				time.Sleep(1 * time.Second)
			}
		}(ctx)
	})
}

// ServeDNS implements the middleware.Handler interface.
func (ztn *ztndns) ServeDNS(ctx context.Context, w dns.ResponseWriter, r *dns.Msg) (int, error) {

	id, _ := GlobalTransactionLock.RLock()

	defer GlobalTransactionLock.RUnlock(id)

	ztn.RefreshPfconfig(ctx)

	state := request.Request{W: w, Req: r}

	a := new(dns.Msg)
	a.SetReply(r)
	a.Compress = true
	a.Authoritative = true
	var rr dns.RR

	for i := 0; i < len(ztn.HostIP); i++ {
		if ztn.HostIP[i].ComputerName.MatchString(state.QName()) {
			rr = new(dns.A)
			rr.(*dns.A).Hdr = dns.RR_Header{Name: state.QName(), Rrtype: dns.TypeA, Class: state.QClass(), Ttl: 60}
			rr.(*dns.A).A = ztn.HostIP[i].Ip
			a.Answer = []dns.RR{rr}
			state.SizeAndDo(a)
			w.WriteMsg(a)
			return 0, nil
		}
	}

	return ztn.Next.ServeDNS(ctx, w, r)
}

// Name implements the Handler interface.
func (ztn *ztndns) Name() string { return "ztndns" }

func (ztn *ztndns) DbInit(ctx context.Context) error {

	var err error

	db, err := db.DbFromConfig(ctx)
	sharedutils.CheckError(err)
	ztn.Db = db

	ztn.DNSAudit, err = ztn.Db.Prepare("insert into dns_audit_log (ip, mac, qname, qtype, scope ,answer) VALUES (?, ?, ?, ?, ?, ?)")
	if err != nil {
		fmt.Fprintf(os.Stderr, "ztndns: database security_event prepared statement error: %s", err)
		return err
	}

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error while connecting to database: %s", err))
		return err
	}

	go func() {
		for {
			ztn.Db.Ping()
			time.Sleep(5 * time.Second)
		}
	}()

	return nil
}

// logreply will log in the db the dns answer
func (ztn *ztndns) logreply(ctx context.Context, ip string, mac string, qname string, qtype string, reply *dns.Msg, scope string) {
	var b bytes.Buffer
	var re = regexp.MustCompile(`\s+`)

	for _, rr := range reply.Answer {
		text := re.ReplaceAllString(rr.String(), " ")
		b.WriteString(text)
		b.WriteString(" \n ")
	}
	if ztn.recordDNS {
		ztn.DNSAudit.ExecContext(ctx, ip, mac, strings.TrimRight(qname, "."), qtype, scope, strings.TrimRight(b.String(), " \n "))
	}
}
