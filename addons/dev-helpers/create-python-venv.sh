#!/bin/bash

PF_DIR=/usr/local/pf
pushd $PF_DIR

/usr/bin/python3 -m venv --system-site-packages $PF_DIR/python

$PF_DIR/python/bin/pip3 install --upgrade --pre ldap3==2.10.2rc2
