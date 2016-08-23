# PacketFence load generator

This toolkit allows to generate DHCP, HTTP, RADIUS EAP-PEAP and RADIUS accounting packets to a PacketFence server

## Installation

### Required Perl modules
You might want to use CPAN to install theses modules
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

## Importing the users in your Active directory

You then need to import the users in `mock_data.csv` in your Active Directory (or any other directory)

To do so, put the powershell script `import-users.ps1` as well as `mock_data.csv` in a directory directly on your Active Directory server.

Then execute powershell as Administrator and then switch directory to where you put the two files above.
Then, launch the script and make sure the users were imported afterwards.

## Importing the iplog information

So portal tests succeed, you need to import the DHCP MAC/IP binding inside the database. In order to do so, execute the following:

```
# /usr/local/pf/addons/stress-tester/import-dhcp.pl
```

## Configure PacketFence

Make sure, you configure PacketFence so that the users that were imported can authenticate both via ntlm_auth and via the authentication sources.

## Using the test plan

Run the plan using the following command : 

```
# PATH=$PATH:`pwd` ./run_plan long.conf 
```

The output will be the ones of the commands. In the case of someload, it outputs a report before exiting.

