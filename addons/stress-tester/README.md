# PacketFence load generator

This toolkit allows to generate DHCP, HTTP, RADIUS EAP-PEAP and RADIUS accounting packets to a PacketFence server

## Installation

### Pre-requirements

You will need libpcap devel (libpcap-dev on Debian), gcc and make installed

### Required Perl modules
You might want to use CPAN to install theses modules
* Net::DHCP::Packet
* Net::DHCP::Constants
* Getopt::Long
* IO::Socket::INET
* Config::IniFiles
* Log::Log4perl

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

## Portal capacity testing with k6

`someload` is great for plan-based mixed load, but for finding the captive
portal's ceiling and bottleneck you usually want: a ramp profile, per-VU
cookies (registration flow), and p95/p99 latency reporting. `portal_static.js`
covers that with [k6](https://k6.io).

### Setup on the load-gen box (Debian 12)

```
sudo gpg -k && sudo gpg --no-default-keyring \
  --keyring /usr/share/keyrings/k6-archive-keyring.gpg \
  --keyserver hkp://keyserver.ubuntu.com:80 \
  --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" \
  | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt update && sudo apt install -y k6
```

### Running the baseline

```
# Through haproxy (real-world path)
TARGET=http://<pf-host-ip> k6 run portal_static.js

# Bypass haproxy, hit httpd.portal container directly (container exposes :8080 on host)
TARGET=http://<pf-host-ip>:8080 k6 run portal_static.js

# Constant load instead of ramp
VUS=500 DURATION=5m TARGET=http://<pf-host-ip> k6 run portal_static.js
```

The script uses `?mac=02:00:00:XX:XX:XX` so every VU/iteration looks like a
distinct device to PF.

### Sampling on the PF server during the run

```
chmod +x portal_probe.sh
./portal_probe.sh 5    # sample every 5s until Ctrl-C
```

Reports haproxy/httpd.portal container CPU, MariaDB `Threads_running`,
pfqueue depth (general + pfdhcplistener), Redis memory.

### Reading the results

| Symptom | Likely cause |
|---|---|
| p95 climbs sharply at N VUs but errors stay low | Apache `MaxRequestWorkers` cap on httpd.portal |
| 5xx errors jump | haproxy backend exhausted or mod_perl worker crashes |
| Direct `:8080` much faster than haproxy `:80` | haproxy is the bottleneck (tune `maxconn`, `nbthread`) |
| Direct only marginally faster | mod_perl is the bottleneck |
| Latency spiky p99, fine p50 | DB connection contention / Redis stalls — check `portal_probe.sh` |

