package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"

	"github.com/inverse-inc/packetfence/go/galeraautofix/mariadb"
	"github.com/inverse-inc/packetfence/go/log"
)

const (
	MSG_SET_SEQNO = "set_seqno"
)

var handlers = map[string]func(ctx context.Context, message MessageInbound) error{
	MSG_SET_SEQNO: handleMsgSetSeqno,
}

type MessageOutbound struct {
	Type string
	Args interface{}
}

type MessageInbound struct {
	Type string
	Args json.RawMessage
}

func sendMessage(ctx context.Context, conn net.Conn, t string, payload interface{}) error {
	message := MessageOutbound{
		Type: t,
		Args: payload,
	}
	jsonPayload, err := json.Marshal(message)
	if err != nil {
		return err
	}

	handleMessage(ctx, jsonPayload)

	fmt.Fprint(conn, jsonPayload)
	return nil
}

func handleMessage(ctx context.Context, from net.IP, payload []byte) error {
	message := MessageInbound{}
	err := json.Unmarshal(payload, &message)
	if err != nil {
		return err
	}

	if f, ok := handlers[message.Type]; ok {
		return f(ctx, from, message)
	} else {
		err := "No handler for message type: " + message.Type
		log.LoggerWContext(ctx).Error(err)
		return errors.New(err)
	}
}

func handleMsgSetSeqno(ctx context.Context, from net.IP, message MessageInbound, nodes *NodeList) error {
	seqno := mariadb.DefaultSeqno
	err := json.Unmarshal(message.Args, &seqno)
	if err != nil {
		log.LoggerWContext(ctx).Error("Unable to parse the sequence number from the message: " + err.Error())
		return ctx, err
	}

	for _, node := range nodes.Nodes {
		if node.IP == from {
			log.LoggerWContext(ctx).Debug(fmt.Sprintf("Recording sequence number %d for %s", seqno, node.IP))
		}
	}

	return ctx, nil
}
