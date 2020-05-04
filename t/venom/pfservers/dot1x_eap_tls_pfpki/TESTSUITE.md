# dot1x_eap_tls_pfpki

## Requirements

### Global config steps
1. Create dot1x_eap_tls role

## Scenario steps
1. Create eap_tls user with dot1x_eap_tls role
1. Create Root CA
1. Create user certificate template
1. Create PacketFence PKI provisioner configuration
   1. Select your template
   1. Select role: dot1x_eap_tls_role
   1. Select type of certificate to generate (MAC or user)

### Node01
1. Create RADIUS request (MAC Authentication) to go on portal
1. Register on portal

## Teardown steps
Add steps
