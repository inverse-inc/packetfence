# Configurator

## Requirements
PacketFence server has been provisionned using Vagrant and Ansible and is in
following state:
- Dynamic IP assigned on **first** network card by hypervisor (used as Vagrant
  management). Default gateway used this interface.
- Static IP assigned on **second** network card by Vagrant (used as management
  interface for PacketFence)
- Machine hostname has been set based on Ansible inventory
- OS at latest version
- Latest packetfence packages installed
- iptables configuration adjusted for Vagrant and MailHog
- Environment variables used for secrets and unit tests have been set
- Venom, psonoci and MailHog are installed

## Scenario steps

### Optional step
1. Configure first interface as dhcp-listener (internet interface)

This step is really specific to vagrant-libvirt. Configurator will switch interface from
dynamic state (DHCP) to static state. Consequently, when DHCP lease reachs end time,
Vagrant will not be able to reach anymore PacketFence server because it rely
on DHCP lease assigned to VM.
As a workaround, we start `dhclient` as a daemon only for this interface with
a specific config to **not** override `/etc/resolv.conf`: PacketFence server
can have two IP addresses one static and another one dynamic.

### Step 1
1. Configure second interface as management with portal daemon (to test other
   feature later)
1. Configure third and fourth interface (registration and isolation
   interfaces) with DHCP enabled
1. Configure two DNS servers: a public DNS server and future AD

### Step 2
1. Start MariaDB
1. Check MariaDB connection
1. Secure MariaDB installation which create root password
2. Create pf database with schema
2. Create database user pf
1. [ ] Validate database state
3. Config pf database in PacketFence
1. Save MariaDB password in ~/.my.cnf file for unit tests
2. Configure alerting
2. Send a test mail
1. [ ] Validate mail received by MailHog
2. Configure general settings (domain, hostname and timezone)
2. Restart MariaDB to take timezone change into account
2. Create admin account for the web admin and password

### Step 3
1. Get Fingerbank API key using `psonoci`
1. Configure Fingerbank API key (need Internet access to query Fingerbank API)
1. Check email associated to Fingerbank API key: it means that API has been
   correctly reached

### Custom step before starting services
Can certainly be done during step4

1. [X] Configure timeout of API token (for next test suites)
1. [X] Decrease forks necessary
1. [X] Run configreload hard to apply changes made directly in config file
1. [X] Put log level to debug to simplify post-mortem when integration tests failed

### Step 4
1. Restart packetfence-config:
   configurator/system_service/packetfence-config/restart, POST
2. Update systemd: /configurator/service/pf/update_systemd POST
1. Restart haproxy-admin: configurator/service/haproxy-admin/restart POST
1. Start PacketFence and Fingerbank services: configurator/service/pf/start POST
1. Disable configurator, PATCH: configurator/config/base/advanced + custom
   changes
2. [ ] Validate that default page is not configurator anymore

### Validation step
1. Check if the configurator is disabled
1. Check if all services are running

## Teardown steps
1. Cleanup mail in MailHog Inbox

### Additional notes

- Only a VLAN enforcement setup is configured even if an inline interface can
  be configured. A dedicated inline scenario will take care of that.

- No `Authorization` header because configurator is token-less.

- This test suite need to be self-contained to test everything before going
  further.
  
- Minor use of common dir because all API calls are specific to configurator
  and will not be used after this test suite.

### Step 1
 
 * PacketFence will transform each dynamic interface into a static
   interface. First interface will have a static IP address which doesn't
   seems to cause issue with libvirt.
   
 * IP for registration and isolation networks can't be .1 because hypervisor
   already have it.
   
 * We don't change hostname for now because it requires a reboot at end of configurator.

### Step 2

  * tracking-config is enabled by default, so we don't change anything. API
    call is not tested.
