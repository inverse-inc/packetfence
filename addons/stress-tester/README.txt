# PacketFence load generator

This toolkit allows to generate DHCP, HTTP, RADIUS EAP-PEAP and RADIUS accounting packets to a PacketFence server

## Installation

### Required Perl modules
* Net::DHCP::Packet
* Net::DHCP::Constants
* Getopt::Long
* IO::Socket::INET

### Compiling someload

You first need to install Go and setup your gospace : https://golang.org/doc/install

Then in your gospace : 

```
# go get github.com/julsemaan/someload
# go install someload.go
```

Then place the executable `someload` into this directory.

### Installing radclient

Then install radclient on the machine which is available with FreeRADIUS and make sure it is available in your path.

### Installing eapol_test

Next install eapol_test : https://wiki.inverse.ca/focus/derek/eapol_test and make sure it is available in your path.

## Creating a test plan

A test plan contains a list of commands to execute that will generate the load.

They can be defered using `delay_by`

The command itself is in charge of exiting after the right amount of time as the planner will not kill the command.

See the example plan in plan.conf.example

## Using the test plan

Run the plan using the following command : 

```
# PATH=$PATH:`pwd` ./run_plan long.conf 
```

The output will be the ones of the commands. In the case of someload, it outputs a report before exiting.

