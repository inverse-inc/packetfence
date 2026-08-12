#!/bin/bash

set -e

CERTS_DIR=/usr/local/pf/raddb/certs
# Host-mounted state directory so the generated RadSec/EAP identity (and the
# expensive DH parameters) survive container recreation.
PERSIST_DIR=/usr/local/pf/certs-persist

mkdir -p "$PERSIST_DIR"

if [ -f "$PERSIST_DIR/server.pem" ]; then
    echo "Restoring persisted raddb certs"
    cp -a "$PERSIST_DIR"/. "$CERTS_DIR"/
else
    echo "Generating raddb certs (first start)"
    make -C "$CERTS_DIR"
    cp -a "$CERTS_DIR"/. "$PERSIST_DIR"/
fi
