<template>
  <b-row>
    <pf-sidebar v-model="sections"></pf-sidebar>
    <b-col cols="12" md="9" xl="10" class="mt-3 mb-3">
      <transition name="slide-bottom">
        <router-view></router-view>
      </transition>
    </b-col>
  </b-row>
</template>

<script>
import pfSidebar from '@/components/pfSidebar'

export default {
  name: 'Nodes',
  components: {
    pfSidebar
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  computed: {
    sections () {
      return [
        {
          name: this.$i18n.t('Search'),
          path: '/nodes/search',
          saveSearchNamespace: 'nodes'
        },
        {
          name: this.$i18n.t('Create'),
          path: '/nodes/create',
          can: 'create nodes'
        },
        {
          name: this.$i18n.t('Import'),
          path: '/nodes/import',
          can: 'create nodes'
        },
        {
          name: this.$i18n.t('Standard Searches'),
          items: [
            {
              name: this.$i18n.t('Open Security Events'),
              path: {
                name: 'search',
                query: { query: JSON.stringify({ op: 'and', values: [{ op: 'or', values: [{ field: 'security_event.open_count', op: 'greater_than_equals', value: '1' }] }] }) }
              }
            },
            {
              name: this.$i18n.t('Closed Security Events'),
              path: {
                name: 'search',
                query: { query: JSON.stringify({ op: 'and', values: [{ op: 'or', values: [{ field: 'security_event.close_count', op: 'greater_than_equals', value: '1' }] }] }) }
              }
            },
            {
              name: this.$i18n.t('Offline Nodes'),
              path: {
                name: 'search',
                query: { query: JSON.stringify({ op: 'and', values: [{ op: 'or', values: [{ field: 'online', op: 'not_equals', value: 'on' }] }] }) }
              }
            },
            {
              name: this.$i18n.t('Online Nodes'),
              path: {
                name: 'search',
                query: { query: JSON.stringify({ op: 'and', values: [{ op: 'or', values: [{ field: 'online', op: 'equals', value: 'on' }] }] }) }
              }
            }
          ]
        },
        {
          name: this.$i18n.t('Switch Groups'),
          collapsable: true,
          items: this.switchGroups.map(switchGroup => {
            return {
              name: switchGroup.group || this.$i18n.t('Default'),
              collapsable: true,
              items: switchGroup.switches.filter(sw => sw.id !== 'default').map(sw => {
                return {
                  name: sw.id,
                  caption: sw.description,
                  path: {
                    name: 'search',
                    query: { query: JSON.stringify({ op: 'and', values: [{ op: 'or', values: [{ field: 'locationlog.switch', op: 'equals', value: this.getIpFromCIDR(sw.id) }] }] }) }
                  }
                }
              })
            }
          })
        }
      ]
    },
    roles () {
      return this.$store.state.config.roles
    },
    switches () {
      return this.$store.state.config.switches
    },
    switchGroups () {
      return this.$store.getters['config/groupedSwitches']
    }
  },
  methods: {
    getIpFromCIDR (cidr) {
      return cidr.split('/', 1)[0] || cidr
    }
  },
  created () {
    this.$store.dispatch('config/getRoles')
    this.$store.dispatch('config/getSwitches')
  }
}
</script>
