
# PacketFence Golang library

## Basic setup

This is an initial draft on how to setup/use the PacketFence Golang libraries.

First you must install Golang via the normal instructions (https://golang.org/doc/install) and setup your GOPATH correctly.

Assuming you installed your git repo in /usr/local/pf, you should then symlink /usr/local/pf/go to $GOPATH/src/github.com/inverse-inc/packetfence/go using:

```
# ln -s $GOPATH/src/github.com/inverse-inc/packetfence/go /usr/local/pf/go
```

Once that is done, you should be working in $GOPATH/src/github.com/inverse-inc/packetfence/go and not /usr/local/pf/go so that Golang commands work correctly (they tend to misbehave outside of the GOPATH)

## Pulling the dependencies

Dependencies should be pulled using 'go get' for now until we decide on a proper vendoring. In order to pull the dependencieS

```
# cd $GOPATH/src/github.com/inverse-inc/packetfence/go
# go get ./...
```

## Building the code

All code should be built into a caddy middleware which we'll then use in a Caddyfile to create our recipes. Only reason for not using Caddy would be that the binaries doesn't interact using HTTP (which Caddy can handle at some point). For now, we'll focus only on services using HTTP until we're confortable with caddy.

A local version of caddy is in caddy/caddy. This is a vendored version of caddy which includes the plugins and middlewares for PacketFence.

In order to build the caddy HTTP service:

```
# make pfcaddy
# mv pfcaddy /usr/local/pf/bin/
```

## Creating a service

Once you've built pfcaddy, you can use a Caddyfile to load your middleware and bind it on a specific port:

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

This file should be put in `/usr/local/pf/conf/caddy-services/NAME-OF-SERVICE.conf`

Note how you can control the logger configuration from the Caddyfile. If your middleware (in this example pfsso) uses or calls the logger, you *must* declare it in your Caddyfile.

If your middleware uses statsd, you don't have to configure statsd in your Caddyfile which will result in the packets just not being sent (a dummy statsd client will be created).

You can start pfcaddy with your Caddyfile using the following command:

```
# /usr/local/pf/bin/pfcaddy -conf /usr/local/pf/conf/caddy-services/pfsso.conf
```

You should now create a systemd service for it calling the method above. This part is still to be written as @louismunro will have to show us how to do it.

## Running the tests

Like the perl unit tests, the Golang tests rely on the presence of the test pfconfig process to execute properly.

In order to start the test pfconfig process:

```
# cd /usr/local/pf/t && ./pfconfig-test
```

Then you can proceed to execute all or some of the Golang unit tests:

```
# cd $GOPATH/src/github.com/inverse-inc/packetfence/go
# go test ./...

# cd $GOPATH/src/github.com/inverse-inc/packetfence/go/firewallsso/lib
# go test
```

## TODO

 * Integrate with pfconfig namespace expiration (for now any config change requires a restart)
 * Integrate a vendoring solution
 * I (Julien) don't like the name pfcaddy even though I came up with it. Suggestions on the name are welcome.
 * A lot more things I'm sure...

