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
import network from '@/utils/network'
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
          can: 'master tenant',
          collapsable: true,
          items: this.switchGroupsMembers.map(switchGroup => {
            return {
              name: switchGroup.id || this.$i18n.t('Default'),
              collapsable: true,
              items: switchGroup.members.map(switchGroupMember => {
                return {
                  name: switchGroupMember.id,
                  caption: switchGroupMember.description,
                  path: {
                    name: 'search',
                    query: { query: JSON.stringify({ op: 'and', values: [{ op: 'or', values: [{ field: 'locationlog.switch', op: 'equals', value: network.cidrToIpv4(switchGroupMember.id) }] }] }) }
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
    }
  },
  created () {
    this.$store.dispatch('config/getRoles')
    if (this.$can('master', 'tenant')) {
      this.$store.dispatch('config/getSwitchGroups').then(switchGroups => {
        switchGroups.map((switchGroup, index) => {
          let { id, description, members = [] } = switchGroup
          members = members.map(member => {
            const { id, description } = member
            return { id, description }
          })
          this.$set(this.switchGroupsMembers, index, { id, description, members })
        })
      })
    }
  }
}
</script>
