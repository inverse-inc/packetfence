<template>
  <div>
    <p class="small text-muted">
      {{ $i18n.t('State of the interfaces, static routes, captive DNS responders and DHCP relays the connector applies on its host, as of its last pass, and the listeners it opened for the tunnel.') }}
      <b-link :to="settingsLocation('networking')" replace class="text-nowrap">{{ $i18n.t('Settings > Networking') }}</b-link>
    </p>
    <b-row>
      <b-col lg="6" class="mb-3">
        <h6 class="text-secondary">{{ $i18n.t('Interfaces') }}</h6>
        <b-table-simple v-if="siteNetwork && siteNetwork.interfaces && siteNetwork.interfaces.length" small class="mb-0">
          <b-thead>
            <b-tr>
              <b-th>{{ $i18n.t('Interface') }}</b-th>
              <b-th>{{ $i18n.t('Address') }}</b-th>
              <b-th>{{ $i18n.t('State') }}</b-th>
            </b-tr>
          </b-thead>
          <b-tbody>
            <b-tr v-for="iface in siteNetwork.interfaces" :key="iface.name">
              <b-td class="text-monospace">{{ iface.name }}</b-td>
              <b-td class="text-monospace">{{ iface.cidr }}</b-td>
              <b-td>
                <b-badge :variant="siteNetworkVariant(iface.state)" :title="iface.error || ''">{{ iface.state }}</b-badge>
                <small v-if="iface.error" class="d-block text-danger">{{ iface.error }}<b-link v-if="canViewLogs" class="ml-1 text-nowrap" @click="goToLogs('pfconnector-client')">{{ $i18n.t('View log') }}</b-link></small>
              </b-td>
            </b-tr>
          </b-tbody>
        </b-table-simple>
        <p v-else class="text-muted small mb-0">{{ $i18n.t('No interface configured for this connector.') }}</p>
      </b-col>
      <b-col lg="6" class="mb-3">
        <h6 class="text-secondary">{{ $i18n.t('Static routes') }}</h6>
        <b-table-simple v-if="siteNetwork && siteNetwork.routes && siteNetwork.routes.length" small class="mb-0">
          <b-thead>
            <b-tr>
              <b-th>{{ $i18n.t('Destination') }}</b-th>
              <b-th>{{ $i18n.t('Via') }}</b-th>
              <b-th>{{ $i18n.t('State') }}</b-th>
            </b-tr>
          </b-thead>
          <b-tbody>
            <b-tr v-for="(route, index) in siteNetwork.routes" :key="index">
              <b-td class="text-monospace">{{ route.destination }}</b-td>
              <b-td class="text-monospace">{{ [route.gateway, route.interface].filter(v => v).join(' dev ') }}</b-td>
              <b-td>
                <b-badge :variant="siteNetworkVariant(route.state)" :title="route.error || ''">{{ route.state }}</b-badge>
                <small v-if="route.error" class="d-block text-danger">{{ route.error }}<b-link v-if="canViewLogs" class="ml-1 text-nowrap" @click="goToLogs('pfconnector-client')">{{ $i18n.t('View log') }}</b-link></small>
              </b-td>
            </b-tr>
          </b-tbody>
        </b-table-simple>
        <p v-else class="text-muted small mb-0">{{ $i18n.t('No static route configured for this connector.') }}</p>
      </b-col>
      <b-col v-if="captiveDns.length" lg="5" class="mb-3">
        <h6 class="text-secondary">{{ $i18n.t('Captive DNS') }}</h6>
        <b-table-simple small class="mb-0">
          <b-thead>
            <b-tr>
              <b-th>{{ $i18n.t('Interface') }}</b-th>
              <b-th>{{ $i18n.t('State') }}</b-th>
              <b-th>{{ $i18n.t('Queries') }}</b-th>
            </b-tr>
          </b-thead>
          <b-tbody>
            <b-tr v-for="srv in captiveDns" :key="srv.interface">
              <b-td class="text-monospace">{{ srv.interface }} ({{ srv.ip }})</b-td>
              <b-td>
                <b-badge :variant="srv.state === 'listening' ? 'success' : 'danger'" :title="srv.error || ''">{{ srv.state }}</b-badge>
                <small v-if="srv.error" class="d-block text-danger">{{ srv.error }}<b-link v-if="canViewLogs" class="ml-1 text-nowrap" @click="goToLogs('pfconnector-client')">{{ $i18n.t('View log') }}</b-link></small>
              </b-td>
              <b-td>{{ srv.queries }}</b-td>
            </b-tr>
          </b-tbody>
        </b-table-simple>
      </b-col>
      <b-col v-if="dhcpRelay.length" class="mb-3">
        <h6 class="text-secondary">{{ $i18n.t('DHCP relay') }}</h6>
        <b-table-simple small class="mb-0">
          <b-thead>
            <b-tr>
              <b-th>{{ $i18n.t('Interface') }}</b-th>
              <b-th>{{ $i18n.t('State') }}</b-th>
              <b-th>{{ $i18n.t('Requests') }}</b-th>
              <b-th>{{ $i18n.t('Replies') }}</b-th>
              <b-th>{{ $i18n.t('Dropped') }}</b-th>
            </b-tr>
          </b-thead>
          <b-tbody>
            <b-tr v-for="relay in dhcpRelay" :key="relay.interface">
              <b-td class="text-monospace">{{ relay.interface }} ({{ relay.ip }})</b-td>
              <b-td>
                <b-badge :variant="relayVariant(relay)" :title="relay.error || relay.last_error || ''">{{ relayFailing(relay) && relay.state === 'listening' ? $i18n.t('failing') : relay.state }}</b-badge>
                <small v-if="relay.error || relay.last_error" class="d-block" :class="(relay.error || relayFailing(relay)) ? 'text-danger' : 'text-muted'">
                  <template v-if="!relay.error && relay.last_error_at">{{ $i18n.t('Last error {time}:', { time: formatDate(relay.last_error_at) }) }}</template>
                  {{ relay.error || relay.last_error }}<b-link v-if="canViewLogs" class="ml-1 text-nowrap" @click="goToLogs('pfconnector-client')">{{ $i18n.t('View log') }}</b-link></small>
              </b-td>
              <b-td>{{ relay.requests }}</b-td>
              <b-td>{{ relay.replies }}</b-td>
              <b-td>{{ relay.dropped }}</b-td>
            </b-tr>
          </b-tbody>
        </b-table-simple>
      </b-col>
    </b-row>

    <h6 class="text-secondary">{{ $i18n.t('Ports open on the connector') }}</h6>
    <p class="mb-1 small text-muted">{{ $i18n.t('Listeners the connector opened on its host for the tunnel, and the PacketFence destination each one forwards to.') }}</p>
    <b-table-simple v-if="localBinds.length" small class="mb-0">
      <b-thead>
        <b-tr>
          <b-th>{{ $i18n.t('Connector port') }}</b-th>
          <b-th>{{ $i18n.t('Protocol') }}</b-th>
          <b-th>{{ $i18n.t('Destination') }}</b-th>
        </b-tr>
      </b-thead>
      <b-tbody>
        <b-tr v-for="(bind, index) in localBinds" :key="index">
          <b-td class="text-monospace">{{ bind.local_host || '0.0.0.0' }}:{{ bind.local_port }}</b-td>
          <b-td>{{ bind.local_proto || 'tcp' }}<small v-if="bind.handler" class="text-muted ml-1">({{ bind.handler }})</small></b-td>
          <b-td class="text-monospace">{{ bind.remote_host }}:{{ bind.remote_port }}</b-td>
        </b-tr>
      </b-tbody>
    </b-table-simple>
    <p v-else class="text-muted small mb-0">{{ isConnected ? $i18n.t('No listener reported by the connector.') : $i18n.t('The tunnel is not connected.') }}</p>
  </div>
</template>
<script>
import { computed, inject } from '@vue/composition-api'
import { formatDate, siteNetworkVariant } from '../_composables/useRemoteStatus'
import { relayFailing } from '../_composables/useConnectorHealth'

// listening and answering, listening but failing (useConnectorHealth), down
const relayVariant = relay => {
  if (relay.state !== 'listening')
    return 'danger'
  return relayFailing(relay) ? 'warning' : 'success'
}

export const setup = () => {
  const remote = inject('connectorRemote')
  const { settingsLocation, goToLogs } = inject('connectorTabs')
  // site networking is applied by the connector client: its errors are in
  // that log, when the connector streams it
  const canViewLogs = computed(() => remote.isConnected.value && remote.logFiles.value.includes('pfconnector-client'))
  return {
    ...remote,
    siteNetworkVariant,
    relayFailing,
    relayVariant,
    formatDate,
    settingsLocation,
    goToLogs,
    canViewLogs
  }
}

// @vue/component
export default {
  name: 'the-site-network',
  inheritAttrs: false,
  setup
}
</script>
