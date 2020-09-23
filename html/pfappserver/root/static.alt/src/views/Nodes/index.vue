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
import network from '@/utils/network'

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
  data () {
    return {
      switchGroupsMembers: []
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
              name: this.$i18n.t('Offline Nodes'),
              path: {
                name: 'nodeSearch',
                query: { query: JSON.stringify({ op: 'and', values: [{ op: 'or', values: [{ field: 'online', op: 'not_equals', value: 'on' }] }] }) }
              }
            },
            {
              name: this.$i18n.t('Online Nodes'),
              path: {
                name: 'nodeSearch',
                query: { query: JSON.stringify({ op: 'and', values: [{ op: 'or', values: [{ field: 'online', op: 'equals', value: 'on' }] }] }) }
              }
            }
          ]
        },
        {
          name: this.$i18n.t('Switch Groups'),
          can: 'master tenant',
          collapsable: true,
          loading: this.isLoadingSwitchGroups,
          items: this.switchGroupsMembers.map(switchGroup => {
            return {
              name: switchGroup.id || this.$i18n.t('Default'),
              collapsable: true,
              items: switchGroup.members.map(switchGroupMember => {
                let query
                if (switchGroupMember.id.indexOf('/') === -1) {
                  query = { query: JSON.stringify({ op: 'and', values: [{ op: 'or', values: [{ field: 'locationlog.switch', op: 'equals', value: switchGroupMember.id }] }] }) }
                }
                else {
                  const [start, end] = network.cidrToRange(switchGroupMember.id)
                  query = { query: JSON.stringify({ op: 'and', values: [
                    { op: 'or', values: [{ field: 'locationlog.switch_ip', op: 'greater_than_equals', value: start }] },
                    { op: 'or', values: [{ field: 'locationlog.switch_ip', op: 'less_than_equals', value: end }] }
                  ] }) }
                }
                return {
                  name: switchGroupMember.id,
                  caption: switchGroupMember.description,
                  path: {
                    name: 'nodeSearch',
                    query
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
    isLoadingSwitchGroups () {
      return this.$store.getters['config/isLoadingSwitchGroups']
    }
  },
  created () {
    this.$store.dispatch('config/getRoles')
    if (this.$can('master', 'tenant')) {
      this.$store.dispatch('config/getSwitches').then(switches => {
        this.$set(this, 'switchGroupsMembers', switches.reduce((groups, switche) => {
          const { group = 'Default', id, description } = switche
          const groupIndex = groups.findIndex(g => g.id === group)
          if (groupIndex > -1) {
            groups[groupIndex].members.push({ id, description })
          }
          else {
            groups.push({ id: group, members: [{ id, description }] })
          }
          return groups
        }, []))
      })
    }
  }
}
</script>
