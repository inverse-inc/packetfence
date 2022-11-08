#!/bin/bash

set -o nounset -o pipefail -o errexit

cd /usr/local/pf

rm conf/ssl/server.{crt,key,pem}

rm conf/local_secret

rm raddb/certs/dh raddb/certs/*.{pem,crt,key,csr,p12,txt} raddb/certs/serial
