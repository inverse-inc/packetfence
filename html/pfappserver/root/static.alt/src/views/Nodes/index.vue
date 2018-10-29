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
import pfMixinSavedSearch from '@/components/pfMixinSavedSearch'

export default {
  name: 'Nodes',
  mixins: [
    pfMixinSavedSearch
  ],
  components: {
    pfSidebar,
    'pf-saved-search': pfMixinSavedSearch
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
          name: 'Search',
          path: '/nodes/search'
        },
        {
          name: 'Create',
          path: '/nodes/create',
          can: 'create nodes'
        },
        {
          name: 'Import',
          path: '/nodes/import',
          can: 'import nodes'
        },
        {
          name: 'Standard Searches',
          items: [
            {
              name: 'Open Violations',
              path: {
                name: 'search',
                query: { query: JSON.stringify({ op: 'and', values: [{ op: 'or', values: [{ field: 'violation.open_count', op: 'greater_than_equals', value: '1' }] }] }) }
              }
            },
            {
              name: 'Closed Violations',
              path: {
                name: 'search',
                query: { query: JSON.stringify({ op: 'and', values: [{ op: 'or', values: [{ field: 'violation.close_count', op: 'greater_than_equals', value: '1' }] }] }) }
              }
            },
            {
              name: 'Offline Nodes',
              path: {
                name: 'search',
                query: { query: JSON.stringify({ op: 'and', values: [{ op: 'or', values: [{ field: 'online', op: 'not_equals', value: 'on' }] }] }) }
              }
            },
            {
              name: 'Online Nodes',
              path: {
                name: 'search',
                query: { query: JSON.stringify({ op: 'and', values: [{ op: 'or', values: [{ field: 'online', op: 'equals', value: 'on' }] }] }) }
              }
            }
          ]
        },
        {
          name: 'Switch Groups',
          collapsable: true,
          items: this.switchGroups.map(switchGroup => {
            return {
              name: switchGroup.group,
              collapsable: true,
              items: switchGroup.switches.map(sw => {
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
