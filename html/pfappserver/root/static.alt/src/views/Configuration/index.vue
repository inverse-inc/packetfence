<template>
  <b-row>
    <pf-sidebar v-model="sections"></pf-sidebar>
    <b-col cols="12" md="9" xl="10" class="pt-3 pb-3">
      <transition name="slide-bottom">
        <router-view></router-view>
      </transition>
    </b-col>
  </b-row>
</template>

<script>
import pfSidebar from '@/components/pfSidebar'

export default {
  name: 'Configuration',
  components: {
    pfSidebar
  },
  data () {
    return {
      sections: [
        {
          name: 'Policies and Access Control',
          icon: 'id-card',
          collapsable: true,
          items: [
            { name: 'Roles', path: '/configuration/roles' },
            { name: 'Domains',
              items: [
                { name: 'Active Directory Domains', path: '/configuration/domains' },
                { name: 'REALMS', path: '/configuration/realms' }
              ]
            },
            { name: 'Authentication Sources', path: '/configuration/sources' },
            { name: 'Network Devices',
              items: [
                { name: 'Switches', path: '/configuration/switches' },
                { name: 'Switch Groups', path: '/configuration/switch_groups' }
              ]
            },
            { name: 'Connection Profiles', path: '/configuration/connection_profiles' }
          ]
        },
        {
          name: 'Compliance',
          icon: 'shield-alt',
          collapsable: true,
          items: [
            { name: 'Fingerbank Profiling',
              items: [
                { name: 'General Settings', path: '/configuration/profiling/general_settings' },
                { name: 'Device change detection', path: '/configuration/profiling/device_change_detection' },
                { name: 'Combinations', path: '/configuration/profiling/combinations' },
                { name: 'Devices', path: '/configuration/profiling/devices' },
                { name: 'DHCP Fingerprints', path: '/configuration/profiling/dhcp_fingerprints' },
                { name: 'DHCP Vendors', path: '/configuration/profiling/dhcp_vendors' },
                { name: 'DHCPv6 Fingerprints', path: '/configuration/profiling/dhcpv6_fingerprints' },
                { name: 'DHCPv6 Enterprises', path: '/configuration/profiling/dhcpv6_enterprises' },
                { name: 'MAC Vendors', path: '/configuration/profiling/mac_vendors' },
                { name: 'User Agents', path: '/configuration/profiling/user_agents' }
              ]
            },
            { name: 'Scans',
              items: [
                { name: 'Scan Engines', path: '/configuration/scans/scan_engines' },
                { name: 'WMI Rules', path: '/configuration/scans/wmi_rules' }
              ]
            }
          ]
        },
        {
          name: 'Integration',
          icon: 'puzzle-piece',
          collapsable: true,
          items: [
            { name: 'Firewall SSO', path: '/configuration/firewalls' },
            { name: 'Cisco Mobility Services Engine', path: '/configuration/mse' }
          ]
        },
        {
          name: 'Network Configuration',
          icon: 'project-diagram',
          collapsable: true,
          items: [
            { name: 'Floating Devices', path: '/configuration/floating_devices' }
          ]
        },
        {
          name: 'Advanced Access Configuration',
          icon: 'clipboard-list',
          collapsable: true,
          items: [
            { name: 'Billing Tiers', path: '/configuration/billing_tiers' },
            { name: 'Portal Modules', path: '/configuration/portal_modules' },
            { name: 'Access Duration', path: '/configuration/access_duration' }
          ]
        }
      ]
    }
  }
}
</script>
