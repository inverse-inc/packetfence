# Configurator

## Requirements
1. Management network card need an ip
1. Server need a hostname
1. PacketFence package freshly installed

### Global config steps
1. Pass step 1 configurator
2. Pass step 2 configurator
3. Pass step 3 configurator
4. Start services and check if all work

## Scenario steps
1. Configure interfaces
1. Configure DNS
2. Check Mariadb is running
2. Set root password
2. Create database
2. Create database user pf
2. Check if database user have been created
2. Configure alerting
2. Send a test name
2. Check if the test mail have been received
2. Configure general setting (DHCP, domain, hostname, timezone)
2. Restart Mariadb
2. Create admin account for the web admin and password
2. Check if admin account is present
3. Set Fingerbank key
4. Start PacketFence services
4. Start Fingerbank
4. Check status Fingerbank
4. Disable configurator
4. Do a configreload hard to take into account the disabling of cofigurator
4. Check if the configurator is disabled

## Teardown steps
1. No teardown
