<template>
  <b-tab :title="$i18n.t('Networking')">
    <b-button-group size="sm" class="mb-3">
      <b-button :variant="networkingView === 'tunnel' ? 'primary' : 'outline-primary'" @click="networkingView = 'tunnel'">{{ $i18n.t('Tunnel') }}</b-button>
      <b-button :variant="networkingView === 'dns' ? 'primary' : 'outline-primary'" @click="networkingView = 'dns'">
        {{ $i18n.t('DNS') }} <b-badge pill variant="light" class="ml-1">{{ dnsConnectors.length }}</b-badge>
      </b-button>
    </b-button-group>

    <template v-if="networkingView === 'tunnel'">
      <p class="small text-muted">
        {{ $i18n.t('Forwards through the tunnel, as bound on the PacketFence side. Static connections are configured (RADIUS sources, DNS servers, NTLM authentication); on-demand ones are opened by PacketFence when it reaches the connector or a device behind it.') }}
      </p>
      <b-table :items="tunnelItems" :fields="tunnelColumns.visibleColumns" :busy="isLoading && !status"
        small striped show-empty sort-icon-left class="mb-0">
        <template #empty>
          <base-table-empty :is-loading="isLoading && !status">{{ isConnected ? $i18n.t('No forward is bound for this connector.') : $i18n.t('The tunnel is not connected.') }}</base-table-empty>
        </template>
        <template #head(buttons)>
          <base-search-input-columns :value="tunnelColumns.columns" @input="tunnelColumns.setColumns" />
        </template>
        <template #cell(service)="{ value }">
          {{ value || '-' }}
        </template>
        <template #cell(state)="{ value }">
          <b-badge v-if="stateBadge(value)" :variant="stateBadge(value).variant">{{ stateBadge(value).label }}</b-badge>
          <span v-else class="text-muted">-</span>
        </template>
      </b-table>
    </template>

    <template v-else>
      <p class="small text-muted">
        {{ $i18n.t('DNS servers whose address is routed through this connector. PacketFence forwards queries for their domains through the tunnel.') }}
      </p>
      <b-table :items="dnsItems" :fields="dnsColumns.visibleColumns" :busy="isEquipmentLoading && !equipment"
        small striped show-empty sort-icon-left>
        <template #empty>
          <base-table-empty :is-loading="isEquipmentLoading && !equipment">{{ $i18n.t('No DNS server is located behind this connector.') }}</base-table-empty>
        </template>
        <template #head(buttons)>
          <base-search-input-columns :value="dnsColumns.columns" @input="dnsColumns.setColumns" />
        </template>
        <template #cell(id)="{ value }">
          <router-link :to="{ name: 'connectorsDn', params: { id: value } }">{{ value }}</router-link>
        </template>
        <template #cell(domains)="{ value }">
          {{ (value || []).join(', ') }}
        </template>
        <template #cell(state)="{ value }">
          <b-badge v-if="stateBadge(value)" :variant="stateBadge(value).variant">{{ stateBadge(value).label }}</b-badge>
          <span v-else class="text-muted">-</span>
        </template>
      </b-table>

      <template v-if="dnsConnectors.length">
        <b-form-group :label="$i18n.t('Test a DNS server')" label-cols="auto" class="mx-3 mt-3 mb-2">
          <b-form-select v-model="selectedDnsId" :options="dnsOptions" size="sm" class="w-auto" />
        </b-form-group>
        <the-test v-if="selectedDns" :key="selectedDns.id" :id="selectedDns.id" :form="selectedDns" />
      </template>
    </template>
  </b-tab>
</template>
<script>
import { computed, inject, reactive, ref, watch } from '@vue/composition-api'
import {
  BaseSearchInputColumns,
  BaseTableEmpty
} from '@/components/new/'
import TheTest from '../../dns/_components/TheTest'
import { useTableColumns } from '../_composables/useTableColumns'
import {
  equipmentRows,
  stateBadge,
  staticState,
  tunnelRows
} from '../_composables/useConnectorRows'

const components = {
  BaseSearchInputColumns,
  BaseTableEmpty,
  TheTest
}

const tunnelColumnDefinitions = [
  { key: 'kind', label: 'Kind', sortable: true, visible: true }, // i18n defer
  { key: 'service', label: 'Service', sortable: true, visible: true }, // i18n defer
  { key: 'local_port', label: 'PacketFence-side port', sortable: true, visible: true, tdClass: 'text-monospace' }, // i18n defer
  { key: 'local_proto', label: 'Protocol', sortable: true, visible: true }, // i18n defer
  { key: 'target', label: 'Target', sortable: true, visible: true, tdClass: 'text-monospace' }, // i18n defer
  { key: 'state', label: 'State', sortable: true, visible: true }, // i18n defer
  { key: 'spec', label: 'Spec', sortable: true, visible: false, tdClass: 'text-monospace' }, // i18n defer
  { key: 'local_host', label: 'PacketFence-side host', sortable: true, visible: false, tdClass: 'text-monospace' }, // i18n defer
  { key: 'remote_host', label: 'Target host', sortable: true, visible: false, tdClass: 'text-monospace' }, // i18n defer
  { key: 'remote_port', label: 'Target port', sortable: true, visible: false, tdClass: 'text-monospace' }, // i18n defer
  { key: 'buttons', class: 'text-right p-0', locked: true }
]

const dnsColumnDefinitions = [
  { key: 'id', label: 'Identifier', sortable: true, visible: true }, // i18n defer
  { key: 'ip', label: 'IP Address', sortable: true, visible: true, tdClass: 'text-monospace' }, // i18n defer
  { key: 'pfconnector_port', label: 'Tunnel port', sortable: true, visible: true, tdClass: 'text-monospace' }, // i18n defer
  { key: 'domains', label: 'Domains', visible: true }, // i18n defer
  { key: 'state', label: 'Tunnel state', sortable: true, visible: true }, // i18n defer
  { key: 'port', label: 'Port', sortable: true, visible: false, tdClass: 'text-monospace' }, // i18n defer
  { key: 'buttons', class: 'text-right p-0', locked: true }
]

export const setup = () => {
  const remote = inject('connectorRemote')
  const { networkingView } = inject('connectorTabs')
  const { status, equipment, networks, dnsConnectors } = remote

  const rows = computed(() => equipmentRows(equipment.value, networks.value))
  const tunnelItems = computed(() => tunnelRows(status.value, dnsConnectors.value, rows.value))
  const dnsItems = computed(() => dnsConnectors.value.map(dns => ({
    ...dns,
    state: staticState(status.value, { port: dns.pfconnector_port, host: dns.ip })
  })))

  const tunnelColumns = reactive(useTableColumns('connectorsTunnel::columns', tunnelColumnDefinitions))
  const dnsColumns = reactive(useTableColumns('connectorsDnsConnectors::columns', dnsColumnDefinitions))

  const selectedDnsId = ref(null)
  const dnsOptions = computed(() => dnsConnectors.value.map(dns => ({ value: dns.id, text: `${dns.id} (${dns.ip})` })))
  watch(dnsConnectors, items => {
    if (!items.find(item => item.id === selectedDnsId.value))
      selectedDnsId.value = items.length ? items[0].id : null
  }, { immediate: true })
  const selectedDns = computed(() => dnsConnectors.value.find(item => item.id === selectedDnsId.value))

  return {
    ...remote,
    networkingView,
    tunnelItems,
    dnsItems,
    tunnelColumns,
    dnsColumns,
    selectedDnsId,
    dnsOptions,
    selectedDns,
    stateBadge
  }
}

// @vue/component
export default {
  name: 'tab-networking',
  inheritAttrs: false,
  components,
  setup
}
</script>
