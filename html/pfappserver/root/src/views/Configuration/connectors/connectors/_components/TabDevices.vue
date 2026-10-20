<template>
  <b-tab>
    <template #title>
      {{ $i18n.t('Devices') }}
      <b-badge v-if="items.length" pill variant="light" class="ml-1 border">{{ items.length }}</b-badge>
    </template>
    <p class="small text-muted">
      {{ $i18n.t('Configured equipment whose IP address is routed through this connector, based on its networks.') }}
      <template v-if="networks.length">
        {{ $i18n.t('Networks') }}:
        <b-badge v-for="network in networks" :key="network" variant="light" class="border mr-1 text-monospace">{{ network }}</b-badge>
      </template>
    </p>
    <b-alert :show="!!equipmentError" variant="warning">{{ equipmentError }}</b-alert>
    <b-table :items="items" :fields="columns.visibleColumns" :busy="isEquipmentLoading && !equipment"
      small striped show-empty sort-icon-left class="mb-0">
      <template #empty>
        <base-table-empty :is-loading="isEquipmentLoading && !equipment">{{ $i18n.t('No configured equipment is located behind this connector.') }}</base-table-empty>
      </template>
      <template #head(buttons)>
        <base-search-input-columns :value="columns.columns" @input="columns.setColumns" />
      </template>
      <template #cell(id)="{ item, value }">
        <router-link v-if="item.routeName" :to="{ name: item.routeName, params: { id: value } }">{{ value }}</router-link>
        <template v-else>{{ value }}</template>
      </template>
      <template #cell(ips)="{ value }">
        {{ (value || []).join(', ') }}
      </template>
      <template #cell(routed_via)="{ value }">
        {{ value || '-' }}
      </template>
      <template #cell(state)="{ value }">
        <b-badge v-if="stateBadge(value)" :variant="stateBadge(value).variant">{{ stateBadge(value).label }}</b-badge>
        <span v-else class="text-muted">-</span>
      </template>
    </b-table>
  </b-tab>
</template>
<script>
import { computed, inject, reactive } from '@vue/composition-api'
import {
  BaseSearchInputColumns,
  BaseTableEmpty
} from '@/components/new/'
import { useTableColumns } from '../_composables/useTableColumns'
import {
  equipmentRows,
  stateBadge,
  staticState
} from '../_composables/useConnectorRows'

const components = {
  BaseSearchInputColumns,
  BaseTableEmpty
}

const columnDefinitions = [
  { key: 'category', label: 'Category', sortable: true, visible: true }, // i18n defer
  { key: 'id', label: 'Identifier', sortable: true, visible: true }, // i18n defer
  { key: 'type', label: 'Type', sortable: true, visible: true }, // i18n defer
  { key: 'description', label: 'Description', sortable: true, visible: true }, // i18n defer
  { key: 'ips', label: 'IP Address(es)', visible: true, tdClass: 'text-monospace' }, // i18n defer
  { key: 'routed_via', label: 'Routed via', sortable: true, visible: false, tdClass: 'text-monospace' }, // i18n defer
  { key: 'state', label: 'Tunnel state', sortable: true, visible: false }, // i18n defer
  { key: 'buttons', class: 'text-right p-0', locked: true }
]

export const setup = () => {
  const remote = inject('connectorRemote')
  const { status, equipment, networks, dnsConnectors } = remote

  // Only RADIUS sources and DNS servers have a static connection whose bound
  // state tells whether they are reachable through the tunnel.
  const deviceState = row => {
    if (row.group === 'dns_connectors') {
      const dns = dnsConnectors.value.find(item => item.id === row.id)
      return (dns)
        ? staticState(status.value, { port: dns.pfconnector_port, host: dns.ip })
        : null
    }
    if (row.group === 'authentication_sources' && row.type === 'RADIUS')
      return row.ips.reduce((state, ip) => state || staticState(status.value, { host: ip, proto: 'udp' }), null)
    return null
  }

  const items = computed(() => equipmentRows(equipment.value, networks.value)
    .map(row => ({ ...row, state: deviceState(row) })))

  const columns = reactive(useTableColumns('connectorsDevices::columns', columnDefinitions))

  return {
    ...remote,
    items,
    columns,
    stateBadge
  }
}

// @vue/component
export default {
  name: 'tab-devices',
  inheritAttrs: false,
  components,
  setup
}
</script>
