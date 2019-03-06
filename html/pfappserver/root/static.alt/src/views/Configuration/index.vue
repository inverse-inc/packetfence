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
          name: this.$i18n.t('Policies and Access Control'),
          icon: 'id-card',
          collapsable: true,
          items: [
            { name: this.$i18n.t('Roles'), path: '/configuration/roles' },
            { name: this.$i18n.t('Domains'),
              items: [
                { name: this.$i18n.t('Active Directory Domains'), path: '/configuration/domains' },
                { name: this.$i18n.t('REALMS'), path: '/configuration/realms' }
              ]
            },
            { name: this.$i18n.t('Authentication Sources'), path: '/configuration/sources' },
            { name: this.$i18n.t('Network Devices'),
              items: [
                { name: this.$i18n.t('Switches'), path: '/configuration/switches' },
                { name: this.$i18n.t('Switch Groups'), path: '/configuration/switch_groups' }
              ]
            },
            { name: this.$i18n.t('Connection Profiles'), path: '/configuration/connection_profiles' }
          ]
        },
        {
          name: this.$i18n.t('Compliance'),
          icon: 'shield-alt',
          collapsable: true,
          items: [
            { name: this.$i18n.t('Fingerbank Profiling'),
              items: [
                { name: this.$i18n.t('General Settings'), path: '/configuration/profiling/general_settings' },
                { name: this.$i18n.t('Device change detection'), path: '/configuration/profiling/device_change_detection' },
                { name: this.$i18n.t('Combinations'), path: '/configuration/profiling/combinations' },
                { name: this.$i18n.t('Devices'), path: '/configuration/profiling/devices' },
                { name: this.$i18n.t('DHCP Fingerprints'), path: '/configuration/profiling/dhcp_fingerprints' },
                { name: this.$i18n.t('DHCP Vendors'), path: '/configuration/profiling/dhcp_vendors' },
                { name: this.$i18n.t('DHCPv6 Fingerprints'), path: '/configuration/profiling/dhcpv6_fingerprints' },
                { name: this.$i18n.t('DHCPv6 Enterprises'), path: '/configuration/profiling/dhcpv6_enterprises' },
                { name: this.$i18n.t('MAC Vendors'), path: '/configuration/profiling/mac_vendors' },
                { name: this.$i18n.t('User Agents'), path: '/configuration/profiling/user_agents' }
              ]
            },
            { name: this.$i18n.t('Scans'),
              items: [
                { name: this.$i18n.t('Scan Engines'), path: '/configuration/scans/scan_engines' },
                { name: this.$i18n.t('WMI Rules'), path: '/configuration/scans/wmi_rules' }
              ]
            }
          ]
        },
        {
          name: this.$i18n.t('Integration'),
          icon: 'puzzle-piece',
          collapsable: true,
          items: [
            { name: this.$i18n.t('Firewall SSO'), path: '/configuration/firewalls' },
            { name: this.$i18n.t('Cisco Mobility Services Engine'), path: '/configuration/mse' },
            { name: this.$i18n.t('Web Services'), path: '/configuration/webservices' },
            { name: this.$i18n.t('Syslog Parsers'), path: '/configuration/pfdetect' },
            { name: this.$i18n.t('Syslog Forwarding'), path: '/configuration/syslog' },
            { name: this.$i18n.t('WRIX'), path: '/configuration/wrix' }
          ]
        },
        {
          name: this.$i18n.t('Advanced Access Configuration'),
          icon: 'clipboard-list',
          collapsable: true,
          items: [
            { name: this.$i18n.t('Captive Portal'), path: '/configuration/captive_portal' },
            { name: this.$i18n.t('Billing Tiers'), path: '/configuration/billing_tiers' },
            { name: this.$i18n.t('PKI Providers'), path: '/configuration/pki_providers' },
            { name: this.$i18n.t('Provisioners'), path: '/configuration/provisionings' },
            { name: this.$i18n.t('Portal Modules'), path: '/configuration/portal_modules' },
            { name: this.$i18n.t('Access Duration'), path: '/configuration/access_duration' },
            { name: this.$i18n.t('Device Registration'), path: '/configuration/device_registrations' }
          ]
        },
        {
          name: this.$i18n.t('Network Configuration'),
          icon: 'project-diagram',
          collapsable: true,
          items: [
            { name: this.$i18n.t('Floating Devices'), path: '/configuration/floating_devices' },
            { name: this.$i18n.t('SSL Certificates'), path: '/configuration/certificates' }
          ]
        }
      ]
    }
  }
}
</script>
