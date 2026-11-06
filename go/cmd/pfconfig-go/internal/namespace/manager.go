package namespace

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"regexp"

	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/builder"
	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/reader"
)

type Request struct {
	Method           string `json:"method,omitempty"`
	Key              string `json:"key,omitempty"` // NAME::SPACE(x);KEY
	NoLastTouchCache string `json:"no_last_touch_cache,omitempty"`
	Encoding         string `json:"encoding,omitempty"`
	LastKey          string `json:"last_key,omitempty"`
	Search           string `json:"search,omitempty"`
	Namespace        string `json:"namespace,omitempty"`
	Light            string `json:"light,omitempty"`
	Index            int    `json:"index,omitempty"`
}

type Manager struct{}

func FloatingDevices(ctx context.Context, request *Request) (any, error) {
	conf, err := reader.LoadConf[*builder.FloatingDevicesConf](builder.ConfFilePath)
	if err != nil {
		return nil, err
	}
	fmt.Println(conf)
	return nil, nil
}

type NamespaceFun struct {
	Fun func(ctx context.Context, request *Request) (any, error)
}

var managedNamespaces = map[string]*NamespaceFun{
	"config::FloatingDevices": {FloatingDevices},
}

var queryRegex = regexp.MustCompile(`(\w+(?:\:\:\w+)*)(?:\((.*)\))?(?:;(\w+))?`)

func GetNamespace(s string) *NamespaceFun {
	ns, _ := managedNamespaces[s]
	return ns
}

type Query struct {
	Namespace string
	Overlay   string
	Key       string
}

func ExtractQuery(s string) (Query, error) {
	data := queryRegex.FindStringSubmatch(s)
	if data == nil {
		return Query{}, errors.New("bad key format")
	}
	return Query{
		Namespace: data[1],
		Overlay:   data[2],
		Key:       data[3],
	}, nil
}

func Manage(ctx context.Context, logger *slog.Logger, reqConn net.Conn, request Request) error {
	query, err := ExtractQuery(request.Key)
	if err != nil {
		return err
	}
	ns := GetNamespace(query.Namespace)
	if ns == nil {
		return errors.ErrUnsupported
	}
	if query.Namespace == "config::FloatingDevices" {
		_, err := ns.Fun(ctx, &request)
		if err != nil {
			return err
		}
	}
	return nil
}

/*
	var header [4]byte
	binary.LittleEndian.PutUint32(header[:], uint32(len(output)))
	n, err := c.Write(header[:])
	if n != len(header) || err != nil {
		logger.InfoContext(ctx, "write header 1", "err", err.Error())
		return
	}
*/
