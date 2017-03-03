
# PacketFence Golang library

## Basic setup

This is an initial draft on how to setup/use the PacketFence Golang libraries.

First you must install Golang via the normal instructions (https://golang.org/doc/install) and setup your GOPATH correctly.

In order to know which version of go you should be using, you can inspect one of the binaries that was provided with the PacketFence package:

```
strings /usr/local/pf/bin/pfhttpd | egrep -o 'go[0-9]+\.[0-9]+\.[0-9]+'
```

Assuming you installed your git repo in /usr/local/pf, you should then symlink /usr/local/pf/go to $GOPATH/src/github.com/inverse-inc/packetfence/go using:

```
# ln -s /usr/local/pf/go $GOPATH/src/github.com/inverse-inc/packetfence/go
```

Once that is done, you should be working in $GOPATH/src/github.com/inverse-inc/packetfence/go and not /usr/local/pf/go so that Golang commands work correctly (they tend to misbehave outside of the GOPATH)

## Pulling the dependencies

Dependencies should be pulled using 'govendor' which is used for dependency management.

In order to install govendor:

```
# go get -u github.com/kardianos/govendor
```

Then pull the dependencies of PacketFence:

```
# cd $GOPATH/src/github.com/inverse-inc/packetfence/go
# govendor sync
```

## Building the code

All code should be built into a caddy middleware which we'll then use in a Caddyfile to create our recipes. Only reason for not using Caddy would be that the binaries doesn't interact using HTTP (which Caddy can handle at some point). For now, we'll focus only on services using HTTP until we're confortable with caddy.

A local version of caddy is in caddy/caddy. This is a vendored version of caddy which includes the plugins and middlewares for PacketFence.

In order to build the caddy HTTP service:

```
# make pfhttpd
# mv pfhttpd /usr/local/pf/bin/
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
# /usr/local/pf/bin/pfhttpd -conf /usr/local/pf/conf/caddy-services/pfexample.conf
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
ExecStart=/usr/local/pf/bin/pfcaddy -conf /usr/local/pf/conf/caddy-services/pfexample.conf
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

In order to test while taking vendoring into consideration, you need to call govendor instead of go to execute the tests.

Then you can proceed to execute all or some of the Golang unit tests:

```
# cd $GOPATH/src/github.com/inverse-inc/packetfence/go
# govendor test ./...

# cd $GOPATH/src/github.com/inverse-inc/packetfence/go/firewallsso/lib
# govendor test
```

