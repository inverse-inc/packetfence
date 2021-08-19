<template>
  <b-row>
    <section-sidebar v-model="sections" />
    <b-col cols="12" md="9" xl="10" class="py-3">
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
      name: i18n.t('RADIUS Audit Logs'),
      path: '/auditing/radiuslogs/search',
      saveSearchNamespace: 'radiusLogs',
      can: 'read radius_log'
    },
    {
      name: i18n.t('DHCP Option 82'),
      path: '/auditing/dhcpoption82s/search',
      saveSearchNamespace: 'dhcpOption82Logs',
      can: 'read dhcp_option_82'
    },
    {
      name: i18n.t('DNS Audit Logs'),
      path: '/auditing/dnslogs/search',
      saveSearchNamespace: 'dnsLogs',
      can: 'read dns_log'
    },
    {
      name: i18n.t('Admin API Audit Logs'),
      path: '/auditing/admin_api_audit_logs/search',
      saveSearchNamespace: 'adminApiLogs',
      can: 'read admin_api_audit_log'
    },
    {
      name: i18n.t('Live Logs'),
      path: '/auditing/live/',
      can: 'read system'
    }
  ]))

  return {
    sections
  }
}

// @vue/component
export default {
  name: 'Auditing',
  components,
  setup
}
</script>
