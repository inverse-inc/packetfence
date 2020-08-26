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

### Step 1
1. Configure first interface as dhcp-listener (internet interface)
1. Configure second interface as management with portal daemon (to test other
   feature later)
1. Configure third and fourth interface (registration and isolation
   interfaces) with DHCP enabled
1. Configure two DNS servers: a public DNS server and future AD

### Step 2
1. Check MariaDB is running
1. Secure MariaDB installation which create root password
1. Save MariaDB password and socket for next test
2. Create pf database
2. Create database user pf
2. Check if database user have been created
2. Configure alerting
2. Send a test name
2. Check if the test mail have been received
2. Configure general setting (DHCP, domain, hostname, timezone)
2. Restart MariaDB
2. Create admin account for the web admin and password
2. Check if admin account is present
1. Store MariaDB password to use it during unit tests

### Step 3
1. Get Fingerbank API key using `psonoci`
1. Configure Fingerbank API key

### Custom step before starting services
Can certainly be done during step4

1. Configure timeout of API token (for next test suites)
1. Decrease forks necessary
1. Put log level to debug to simplify post-mortem when integration tests failed

### Step 4
1. Restart packetfence-config:
   configurator/system_service/packetfence-config/restart, POST
2. Update systemd: /configurator/service/pf/update_systemd POST
1. Restart haproxy-admin: configurator/service/haproxy-admin/restart POST
1. Start PacketFence and Fingerbank services: configurator/service/pf/start POST
1. Disable configurator, PATCH: configurator/config/base/advanced + custom changes

### Validation step
1. Check if the configurator is disabled
1. Check if all services are running

## Teardown steps
No teardown.

### Additional notes

No `Authorization` header because configurator is token-less.

### Step 1
 
 * PacketFence will transform each dynamic interface into a static
   interface. First interface will have a static IP address which doesn't
   seems to cause issue with libvirt.
   
 * We don't change hostname for now because it requires a reboot at end of configurator
