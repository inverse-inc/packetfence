<template>
  <b-row align-v="start">
    <section-sidebar v-model="sections" />
    <b-col cols="12" md="9" xl="10" class="pt-3 pb-3">
      <transition name="slide-bottom">
        <router-view />
      </transition>
    </b-col>
  </b-row>
</template>

<script>
import SectionSidebar from '@/components/SectionSidebar'
const components = {
  SectionSidebar
}

import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'
const setup = () => {
  const sections = computed(() => ([
    {
      name: i18n.t('Policies and Access Control'),
      path: '/configuration/policies_access_control',
      icon: 'id-card',
      collapsable: true,
      items: [
        { name: i18n.t('Roles'), path: '/configuration/roles' },
        { name: i18n.t('Domains'),
          items: [
            { name: i18n.t('Active Directory Domains'), path: '/configuration/domains', class: 'no-saas' },
            { name: i18n.t('Realms'), path: '/configuration/realms' }
          ]
        },
        { name: i18n.t('Authentication Sources'), path: '/configuration/sources' },
        { name: i18n.t('Network Devices'),
          items: [
            { name: i18n.t('Switches'), path: '/configuration/switches' },
            { name: i18n.t('Switch Groups'), path: '/configuration/switch_groups' }
          ]
        },
        { name: i18n.t('Connection Profiles'), path: '/configuration/connection_profiles' }
      ]
    },
    {
      name: i18n.t('Compliance'),
      path: '/configuration/compliance',
      icon: 'shield-alt',
      collapsable: true,
      items: [
        { name: i18n.t('Fingerbank Profiling'),
          items: [
            { name: i18n.t('General Settings'), path: '/configuration/fingerbank/general_settings' },
            { name: i18n.t('Device change detection'), path: '/configuration/fingerbank/device_change_detection' },
            { name: i18n.t('Combinations'), path: '/configuration/fingerbank/combinations' },
            { name: i18n.t('Devices'), path: '/configuration/fingerbank/devices' },
            { name: i18n.t('DHCP Fingerprints'), path: '/configuration/fingerbank/dhcp_fingerprints' },
            { name: i18n.t('DHCP Vendors'), path: '/configuration/fingerbank/dhcp_vendors' },
            { name: i18n.t('DHCPv6 Fingerprints'), path: '/configuration/fingerbank/dhcpv6_fingerprints' },
            { name: i18n.t('DHCPv6 Enterprises'), path: '/configuration/fingerbank/dhcpv6_enterprises' },
            { name: i18n.t('MAC Vendors'), path: '/configuration/fingerbank/mac_vendors' },
            { name: i18n.t('User Agents'), path: '/configuration/fingerbank/user_agents' }
          ]
        },
        { name: i18n.t('Network Anomaly Detection'), path: '/configuration/fingerbank/network_behavior_policies' },
        { name: i18n.t('Scan Engines'), path: '/configuration/scan_engines' },
        { name: i18n.t('Security Events'), path: '/configuration/security_events' }
      ]
    },
    {
      name: i18n.t('Integration'),
      path: '/configuration/integration',
      icon: 'puzzle-piece',
      collapsable: true,
      items: [
        { name: i18n.t('Cloud Services'), path: '/configuration/clouds' },
        { name: i18n.t('Event Loggers'), path: '/configuration/event_loggers' },
        { name: i18n.t('Firewall SSO'), path: '/configuration/firewalls' },
        { name: i18n.t('Web Services'), path: '/configuration/webservices' },
        { name: i18n.t('Switch Templates'), path: '/configuration/switch_templates' },
        { name: i18n.t('Event Handlers'), path: '/configuration/pfdetect' },
        { name: i18n.t('Syslog Forwarding'), path: '/configuration/syslog' },
        { name: i18n.t('WRIX'), path: '/configuration/wrix' },
        { name: i18n.t('PKI'),
          items: [
            { name: i18n.t('Certificate Authorities'), path: '/configuration/pki/cas' },
            { name: i18n.t('Templates'), path: '/configuration/pki/profiles' },
            { name: i18n.t('Certificates'), path: '/configuration/pki/certs' },
            { name: i18n.t('Revoked Certificates'), path: '/configuration/pki/revokedcerts' },
            { name: i18n.t('SCEP Servers'), path: '/configuration/pki/scepservers' }
          ]
        },
        { name: i18n.t('Multi-Factor Authentication'), path: '/configuration/mfas' }
      ]
    },
    {
      name: i18n.t('Advanced Access Configuration'),
      path: '/configuration/advanced_access_configuration',
      icon: 'clipboard-list',
      collapsable: true,
      items: [
        { name: i18n.t('Captive Portal'), path: '/configuration/captive_portal' },
        { name: i18n.t('Filter Engines'), path: '/configuration/filter_engines' },
        { name: i18n.t('Billing Tiers'), path: '/configuration/billing_tiers' },
        { name: i18n.t('PKI Providers'), path: '/configuration/pki_providers' },
        { name: i18n.t('Provisioners'), path: '/configuration/provisionings' },
        { name: i18n.t('Portal Modules'), path: '/configuration/portal_modules' },
        { name: i18n.t('Access Duration'), path: '/configuration/access_duration' },
        { name: i18n.t('Self Service Portal'), path: '/configuration/self_services' }
      ]
    },
    {
      name: i18n.t('Network Configuration'),
      path: '/configuration/network_configuration',
      icon: 'project-diagram',
      collapsable: true,
      class: 'no-saas',
      items: [
        { name: i18n.t('Networks'),
          items: [
            { name: i18n.t('Network Settings'), path: '/configuration/network' },
            { name: i18n.t('Interfaces'), path: '/configuration/interfaces' },
            { name: i18n.t('Inline'), path: '/configuration/inline' },
            { name: i18n.t('Fencing'), path: '/configuration/fencing' },
            { name: i18n.t('Device Parking'), path: '/configuration/parking' }
          ]
        },
        { name: i18n.t('SNMP'), path: '/configuration/snmp_traps' },
        { name: i18n.t('Floating Devices'), path: '/configuration/floating_devices' }
      ]
    },
    {
      name: i18n.t('System Configuration'),
      path: '/configuration/system_configuration',
      icon: 'cogs',
      collapsable: true,
      items: [
        { name: i18n.t('Main Configuration'),
          items: [
            { name: i18n.t('General Configuration'), path: '/configuration/general' },
            { name: i18n.t('Alerting'), path: '/configuration/alerting' },
            { name: i18n.t('Monit'), path: '/configuration/monit', class: 'no-saas' },
            { name: i18n.t('Advanced'), path: '/configuration/advanced' },
            { name: i18n.t('Maintenance'), path: '/configuration/maintenance_tasks' },
            { name: i18n.t('Services'), path: '/configuration/services', class: 'no-saas' }
          ]
        },
        { name: i18n.t('Database'),
          items: [
            { name: i18n.t('General'), path: '/configuration/database_general' },
            { name: i18n.t('Advanced'), path: '/configuration/database_advanced' },
            { name: i18n.t('ProxySQL'), path: '/configuration/database_proxysql' }
          ]
        },
        { name: i18n.t('Cluster'), path: '/configuration/active_active', class: 'no-saas' },
        { name: i18n.t('FleetDM'), path: '/configuration/fleetdm', class: 'no-saas'},
        { name: i18n.t('RADIUS'),
          items: [
            { name: i18n.t('General'), path: '/configuration/radius/general' },
            { name: i18n.t('EAP Profiles'), path: '/configuration/radius/eap' },
            { name: i18n.t('TLS Profiles'), path: '/configuration/radius/tls' },
            { name: i18n.t('Fast Profiles'), path: '/configuration/radius/fast' },
            { name: i18n.t('PKI SSL Certificates'), path: '/configuration/radius/ssl' },
            { name: i18n.t('OCSP Profiles'), path: '/configuration/radius/ocsp' }
          ]
        },
        { name: i18n.t('DNS Configuration'), path: '/configuration/dns' },
        { name: i18n.t('Admin Access'), path: '/configuration/admin_roles' },
        { name: i18n.t('Admin Login'), path: '/configuration/admin_login' },
        { name: i18n.t('SSL Certificates'), path: '/configuration/certificates' },
        { name: i18n.t('Connectors'), path: '/configuration/connectors' }
      ]
    }
  ]))

  return {
    sections
  }
}

// @vue/component
export default {
  name: 'Configuration',
  components,
  setup
}
</script>
