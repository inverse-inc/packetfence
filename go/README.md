
# PacketFence go library

## Basic setup

This is an initial draft on how to setup/use the PacketFence go libraries.

First you must install golang via the normal instructions (https://golang.org/doc/install) and setup your GOPATH correctly.

Assuming you installed your git repo in /usr/local/pf, you should then symlink /usr/local/pf/go to $GOPATH/src/github.com/inverse-inc/packetfence/go using:

```
# ln -s $GOPATH/src/github.com/inverse-inc/packetfence/go /usr/local/pf/go
```

Once that is done, you should be working in $GOPATH/src/github.com/inverse-inc/packetfence/go and not /usr/local/pf/go so that go commands work correctly (they tend to misbehave outside of the GOPATH)

## Running the tests

Like the perl unit tests, the golang tests rely on the presence of the test pfconfig process to execute properly.

In order to start the test pfconfig process:

```
# cd /usr/local/pf/t && ./pfconfig-test
```

Then you can proceed to execute all or some of the golang unit tests:

```
# cd $GOPATH/src/github.com/inverse-inc/packetfence/go
# go test ./...

# cd $GOPATH/src/github.com/inverse-inc/packetfence/go/firewallsso/lib
# go test
```

## TODO

 * Migrate to the improved logging framework created in the fingerbank processor: github.com/fingerbank/processor/tree/master/log
 * Integrate with pfconfig namespace expiration (for now any config change requires a restart)
 * A lot more things I'm sure...

