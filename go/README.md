
# PacketFence Golang library

## Basic setup

This is an initial draft on how to setup/use the PacketFence Golang libraries.

In order to bootstrap your environment from the version of /usr/local/pf/sbin/pfhttpd

```
# cd /usr/local/pf/go
# make go-env
```

You should then source your .bashrc to get the new environment variables

```
# source ~/.bashrc
```

Once that is done, you should be working in $GOPATH/src/github.com/inverse-inc/packetfence/go and not /usr/local/pf/go so that Golang commands work correctly (they tend to misbehave outside of the GOPATH)

Your GOPATH will be setup in ~/gospace when using `make go-env`.

## Pulling the dependencies

Dependencies use go modules and will be fetched automatically during build time

You will also need ipset-devel which can be installed using the following command:

```
# yum install ipset-devel
```

## Building the code

All code should be built into a caddy middleware which we'll then use in a Caddyfile to create our recipes. Only reason for not using Caddy would be that the binaries doesn't interact using HTTP (which Caddy can handle at some point). For now, we'll focus only on services using HTTP until we're confortable with caddy.

A local version of caddy is in caddy/caddy. This is a vendored version of caddy which includes the plugins and middlewares for PacketFence.

In order to build the caddy HTTP service:

```
# make pfhttpd
# mv pfhttpd /usr/local/pf/sbin/
```
Do the same to build pfdns, pfdhcp, pfdetect and pfstats:

```
# make pfdns
# mv pfdns /usr/local/pf/sbin/
# make pfdhcp
# mv pfdhcp /usr/local/pf/sbin/
# make pfdetect
# mv pfdetect /usr/local/pf/sbin/
# make pfstats
# mv pfstats /usr/local/pf/sbin/
```

## Creating a service

Once you've built pfhttpd, you can use a Caddyfile to load your middleware and bind it on a specific port:

```
localhost:1234 {
  logger {
    requesthistory 100
    level DEBUG
  }
  statsd {
    proto udp
    prefix pfsso
  }
  pfsso
}
```

This file should be put in `/usr/local/pf/conf/caddy-services/pfexample.conf`

Note how you can control the logger configuration from the Caddyfile. If your middleware (in this example pfsso) uses or calls the logger, you *must* declare it in your Caddyfile.

If your middleware uses statsd, you don't have to configure statsd in your Caddyfile which will result in the packets just not being sent (a dummy statsd client will be created).

You can start pfhttpd with your Caddyfile using the following command:

```
# /usr/local/pf/sbin/pfhttpd -conf /usr/local/pf/conf/caddy-services/pfexample.conf
```

Once you have ascertained that the service is working correctly, you need to create an instance of pf::services::manager for it. You will also need to create a unitfile for it in conf/systemd like the following:

```
[Unit]
Description=PacketFence Example Service
Wants=packetfence-base.target packetfence-config.service packetfence-iptables.service
After=packetfence-base.target packetfence-config.service packetfence-iptables.service
Before=packetfence-pfexample.service

[Service]
PIDFile=/usr/local/pf/var/run/pfexample.pid
ExecStart=/usr/local/pf/sbin/pfhttpd -conf /usr/local/pf/conf/caddy-services/pfexample.conf
Restart=on-failure
Slice=packetfence.slice

[Install]
WantedBy=packetfence.target
```

Make sure that the packaging is also updated to copy those files in the /usr/lib/systemd/system directory.

## Running the tests

Like the perl unit tests, the Golang tests rely on the presence of the test pfconfig process to execute properly.

In order to start the test pfconfig process:

```
# cd /usr/local/pf/t && ./pfconfig-test
```

You can proceed to execute all or some of the Golang unit tests:

```
# cd /usr/local/pf/go
# go test ./...

# cd /usr/local/pf/go/firewallsso/lib
# go test
```

In order to run all the tests easily you can also do:

```
cd /usr/local/pf/go
make test
```
