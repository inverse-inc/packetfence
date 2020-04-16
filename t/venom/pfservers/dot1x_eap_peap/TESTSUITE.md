# Test plan

## Requirements

### Global (no impact)
1. Create access duration (global)
1. Create access level (global)
1. Create dot1x roles (global)
1. Create switches and switch groups (global)
1. Checkup (common lib)

## Test suite
1. Join domain
1. Configure REALM
1. Create sources (common lib), need to pass some parameters
1. Create connection profile
1. Run eapol test (common lib)
1. Check RADIUS audit log (common lib)
1. Check node state (common lib)
1. Teardown (optional) 
