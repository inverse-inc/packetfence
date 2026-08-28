<template>
  <div class="card mx-3 mb-3 bg-light">
    <div class="card-body">
      <b-row align-v="center" class="mb-2">
        <b-col>
          <h6 class="mb-0">
            {{ $i18n.t('Equipment Behind This Connector') }}
            <b-badge v-if="equipment" variant="secondary" class="ml-2">{{ totalCount }}</b-badge>
          </h6>
          <small class="text-muted">
            {{ $i18n.t('Configured equipment whose IP address is routed through this connector, based on its networks.') }}
          </small>
        </b-col>
        <b-col cols="auto">
          <b-button size="sm" variant="outline-secondary" :disabled="isLoading" @click="refresh">
            <icon name="sync" :spin="isLoading" class="mr-1" />{{ $i18n.t('Refresh') }}
          </b-button>
        </b-col>
      </b-row>

      <p v-if="networks.length" class="mb-2">
        <span class="text-muted mr-1">{{ $i18n.t('Networks') }}:</span>
        <b-badge v-for="network in networks" :key="network" variant="light" class="border mr-1 text-monospace">{{ network }}</b-badge>
      </p>

      <b-alert :show="!!error" variant="warning" class="mb-2">{{ error }}</b-alert>

      <template v-if="groups.length">
        <div v-for="group in groups" :key="group.title">
          <h6 class="text-secondary">{{ group.title }} <b-badge variant="light" class="border">{{ group.items.length }}</b-badge></h6>
          <b-table-simple small class="mb-3">
            <b-thead>
              <b-tr>
                <b-th>{{ $i18n.t('Identifier') }}</b-th>
                <b-th>{{ $i18n.t('Type') }}</b-th>
                <b-th>{{ $i18n.t('Description') }}</b-th>
                <b-th>{{ $i18n.t('IP Address(es)') }}</b-th>
              </b-tr>
            </b-thead>
            <b-tbody>
              <b-tr v-for="item in group.items" :key="item.id">
                <b-td class="text-monospace">
                  <router-link v-if="group.routeName" :to="{ name: group.routeName, params: { id: item.id } }">{{ item.id }}</router-link>
                  <template v-else>{{ item.id }}</template>
                </b-td>
                <b-td>{{ item.type }}</b-td>
                <b-td>{{ item.description }}</b-td>
                <b-td class="text-monospace">{{ item.ips.join(', ') }}</b-td>
              </b-tr>
            </b-tbody>
          </b-table-simple>
        </div>
      </template>
      <p v-else-if="equipment && !isLoading" class="text-muted mb-0">
        {{ $i18n.t('No configured equipment is located behind this connector.') }}
      </p>
    </div>
  </div>
</template>
<script>
import { computed, onMounted, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import api from '../_api'

export const props = {
  id: {
    type: String
  }
}

export const setup = props => {
  const equipment = ref(null)
  const networks = ref([])
  const error = ref(null)
  const isLoading = ref(false)

  const refresh = () => {
    if (!props.id)
      return
    isLoading.value = true
    api.equipment(props.id).then(response => {
      equipment.value = response.equipment || {}
      networks.value = response.networks || []
      error.value = null
    }).catch(() => {
      error.value = i18n.t('Unable to fetch the equipment located behind this connector.')
    }).finally(() => {
      isLoading.value = false
    })
  }

  const groups = computed(() => {
    const {
      switches = [],
      authentication_sources = [],
      domains = [],
      firewalls = [],
      dns_connectors = []
    } = equipment.value || {}
    return [
      { title: i18n.t('Switches'), routeName: 'switch', items: switches },
      { title: i18n.t('Authentication Sources'), routeName: 'source', items: authentication_sources },
      // Domain UI ids are host-scoped section names, not the bare domain id
      // the config hash exposes: no reliable deep-link.
      { title: i18n.t('Active Directory Domains'), routeName: null, items: domains },
      { title: i18n.t('Firewalls'), routeName: 'firewall', items: firewalls },
      { title: i18n.t('DNS Connectors'), routeName: 'connectorsDn', items: dns_connectors }
    ].filter(group => group.items.length)
  })

  const totalCount = computed(() => groups.value.reduce((count, group) => count + group.items.length, 0))

  onMounted(refresh)

  return {
    equipment,
    networks,
    error,
    isLoading,
    groups,
    totalCount,
    refresh
  }
}

// @vue/component
export default {
  name: 'the-equipment',
  inheritAttrs: false,
  props,
  setup
}
</script>
