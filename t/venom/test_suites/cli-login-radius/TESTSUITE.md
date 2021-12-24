# wireless dot1x_eap_peap

## Requirements
Radius server running

## Global config steps
1. Create Admin Roles
1. Create RADIUS server source
1. Create a REALMS
1. Use this source as proxy in your Realm
1. Forge a RADIUS request with Realm

# On remote RADIUS server, authentication and authorization need to be setup correctly.

## Scenario steps
1. Create Admin Roles 
1. Create RADIUS server source 
1. Create REALMS for the proxy 
1. Start Services (RADIUS TEST)
1. Start Services request (direct and with proxy) 

## Teardown steps
1. Clean the config
1. Stop RADIUS test service
1. Delete files
1. Reload Deamon
1. Generic Teardown
1. Restart RADIUS service

## Additional notes

