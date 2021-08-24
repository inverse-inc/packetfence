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

import { computed, onMounted, ref } from '@vue/composition-api'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'
import network from '@/utils/network'
const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const switchGroupsMembers = ref([])
  const isLoadingSwitchGroups = computed(() => $store.getters['config/isLoadingSwitchGroups'])

  const sections = computed(() => ([
    {
      name: i18n.t('Search'),
      path: '/nodes/search',
      saveSearchNamespace: 'nodes',
      standardSearches: [
        {
          name: i18n.t('Offline Nodes'),
          conditionAdvanced: { op: 'and', values: [{ op: 'or', values: [{ field: 'online', op: 'not_equals', value: 'on' }] }] },
          sortBy: 'last_seen',
          sortDesc: true
        },
        {
          name: i18n.t('Online Nodes'),
          conditionAdvanced: { op: 'and', values: [{ op: 'or', values: [{ field: 'online', op: 'equals', value: 'on' }] }] },
          sortBy: 'last_seen',
          sortDesc: true
        }
      ]
    },
    {
      name: i18n.t('Create'),
      path: '/nodes/create',
      can: 'create nodes'
    },
    {
      name: i18n.t('Import'),
      path: '/nodes/import',
      can: 'create nodes'
    },
    {
      name: i18n.t('Switch Groups'),
      can: 'master tenant',
      collapsable: true,
      loading: isLoadingSwitchGroups.value,
      items: switchGroupsMembers.value.map(switchGroup => {
        return {
          name: switchGroup.id || i18n.t('Default'),
          collapsable: true,
          items: switchGroup.members.map(switchGroupMember => {
            let query
            if ((/^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2})$/.exec(switchGroupMember.id))) { // CIDR
              const [start, end] = network.cidrToRange(switchGroupMember.id)
              query = { query: JSON.stringify({ op: 'and', values: [
                { op: 'or', values: [{ field: 'locationlog.switch_ip', op: 'greater_than_equals', value: start }] },
                { op: 'or', values: [{ field: 'locationlog.switch_ip', op: 'less_than_equals', value: end }] }
              ] }) }
            }
            else if ((/^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})$/.exec(switchGroupMember.id))) { // IPv4
              query = { query: JSON.stringify({ op: 'and', values: [{ op: 'or', values: [{ field: 'locationlog.switch_ip', op: 'equals', value: switchGroupMember.id }] }] }) }
            }
            else { // non-CIDR
              query = { query: JSON.stringify({ op: 'and', values: [{ op: 'or', values: [{ field: 'locationlog.switch', op: 'equals', value: switchGroupMember.id }] }] }) }
            }
            return {
              name: switchGroupMember.id,
              caption: switchGroupMember.description,
              path: { name: 'nodeSearch', query }
            }
          })
        }
      })
    }
  ]))

  onMounted(() => {
    if (acl.$can('master', 'tenant')) {
      $store.dispatch('config/getSwitches').then(switches => {
        switchGroupsMembers.value = switches.reduce((groups, switche) => {
          const { group = 'Default', id, description } = switche
          const groupIndex = groups.findIndex(g => g.id === group)
          if (groupIndex > -1)
            groups[groupIndex].members.push({ id, description })
          else
            groups.push({ id: group, members: [{ id, description }] })
          return groups
        }, [])
      })
    }
  })

  return {
    sections
  }
}

// @vue/component
export default {
  name: 'Nodes',
  components,
  setup
}
</script>
