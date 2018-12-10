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
            { name: 'Authentication Sources', path: '/configuration/sources' }
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
            { name: 'Portal Modules', path: '/configuration/portal_modules' }
          ]
        }
      ]
    }
  }
}
</script>
