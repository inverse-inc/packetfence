#!/bin/bash


/usr/local/pf/t/pfconfig-test ;\
GODEBUG=randseednop=0 PF_SYSTEM_INIT_KEY=$(cat /usr/local/pf/t/data/system_init_key) PFCONFIG_PROTO=unix PFCONFIG_TESTING=y go test "$@"
