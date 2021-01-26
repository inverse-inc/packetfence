<template>
        <b-row>
            <pf-sidebar v-model="sections"></pf-sidebar>
            <b-col cols="12" md="9" xl="10" class="py-3">
                <transition name="slide-bottom">
                    <router-view></router-view>
                </transition>
            </b-col>
        </b-row>
</template>

<script>
import pfSidebar from '@/components/pfSidebar'

export default {
  name: 'Auditing',
  components: {
    pfSidebar
  },
  computed: {
    sections () {
      return [
        {
          name: this.$i18n.t('RADIUS Audit Logs'),
          path: '/auditing/radiuslogs/search',
          saveSearchNamespace: 'radiuslogs',
          can: 'read radius_log'
        },
        {
          name: this.$i18n.t('DHCP Option 82'),
          path: '/auditing/dhcpoption82s/search',
          saveSearchNamespace: 'dhcpoption82s',
          can: 'read dhcp_option_82'
        },
        {
          name: this.$i18n.t('DNS Audit Logs'),
          path: '/auditing/dnslogs/search',
          saveSearchNamespace: 'dnslogs',
          can: 'read dns_log'
        },
        {
          name: this.$i18n.t('Admin API Audit Logs'),
          path: '/auditing/admin_api_audit_logs/search',
          saveSearchNamespace: 'admin_api_audit_logs',
          can: 'read admin_api_audit_log'
        },
        {
          name: this.$i18n.t('Live Logs'),
          path: '/auditing/live/',
          can: 'read system'
        }
      ]
    }
  }
}
</script>
