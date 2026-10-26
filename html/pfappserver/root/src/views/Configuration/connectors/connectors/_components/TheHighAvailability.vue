<template>
  <b-card no-body>
    <b-card-header class="d-flex align-items-center">
      <h6 class="mb-0">{{ $i18n.t('High Availability') }}</h6>
      <b-badge :variant="haPeersAlive.length ? 'info' : 'warning'" class="ml-2">{{ $i18n.t('VIP') }} {{ ha.vip }}</b-badge>
    </b-card-header>
    <b-card-body class="pb-0">
      <p class="small text-muted mb-2">
        {{ $i18n.t('Point switches, portal redirection and DHCP relays at the virtual IP.') }}
        <b-link :to="settingsLocation('networking')" replace class="text-nowrap">{{ $i18n.t('Settings > Networking') }}</b-link>
      </p>
    </b-card-body>
    <b-table-simple small responsive class="mb-0">
      <b-thead>
        <b-tr>
          <b-th>{{ $i18n.t('Host') }}</b-th>
          <b-th>{{ $i18n.t('Role') }}</b-th>
          <b-th>{{ $i18n.t('Version') }}</b-th>
          <b-th>{{ $i18n.t('Since / Last seen') }}</b-th>
          <b-th>{{ $i18n.t('Cache') }}</b-th>
          <b-th>{{ $i18n.t('Status') }}</b-th>
        </b-tr>
      </b-thead>
      <b-tbody>
        <b-tr>
          <b-td class="text-monospace">{{ ha.hostname || (system && system.hostname) }} <small v-if="ha.address" class="text-muted">{{ ha.address }}</small></b-td>
          <b-td>{{ $i18n.t('master') }}</b-td>
          <b-td>{{ system && system.version }}</b-td>
          <b-td>{{ formatDate(ha.since) }}</b-td>
          <b-td><span class="text-muted">{{ $i18n.t('source') }}</span></b-td>
          <b-td><b-badge variant="success">{{ $i18n.t('holds the VIP') }}</b-badge></b-td>
        </b-tr>
        <b-tr v-for="peer in ha.peers" :key="peer.hostname">
          <b-td class="text-monospace">{{ peer.hostname }} <small class="text-muted">{{ peer.address }}</small></b-td>
          <b-td>{{ $i18n.t(peer.state || 'backup') }}<template v-if="peer.priority"> <small class="text-muted">({{ $i18n.t('priority') }} {{ peer.priority }})</small></template></b-td>
          <b-td>{{ peer.version }}</b-td>
          <b-td>{{ formatDate(peer.last_seen) }}</b-td>
          <b-td>
            <b-badge v-if="peer.cache_synced_at" :variant="peer.cache_sync_error ? 'warning' : 'light'" class="border" :title="peer.cache_sync_error || ''">
              {{ $i18n.t('{n} entries', { n: peer.cache_rows || 0 }) }} · {{ formatDate(peer.cache_synced_at) }}
            </b-badge>
            <b-badge v-else variant="warning" :title="peer.cache_sync_error || ''">{{ $i18n.t('not synced') }}</b-badge>
            <b-badge v-if="peer.totp_seed_synced" variant="light" class="border ml-1"
              :title="$i18n.t('This host adopted the terminal TOTP seed of the active host: the same authenticator enrollment opens the terminal on it.')">{{ $i18n.t('TOTP seed') }}</b-badge>
            <b-badge v-else variant="warning" class="ml-1"
              :title="$i18n.t('This host has not adopted the terminal TOTP seed of the active host yet (it syncs every minute over the local network).')">{{ $i18n.t('TOTP seed') }}</b-badge>
          </b-td>
          <b-td class="text-nowrap">
            <b-badge :variant="peer.alive ? 'success' : 'danger'">{{ peer.alive ? $i18n.t('alive') : $i18n.t('not reporting') }}</b-badge>
            <b-button v-if="peer.alive && canUpdate" size="sm" variant="outline-primary" class="ml-2 py-0"
              :disabled="!isConnected || isSwitching"
              :title="$i18n.t('Move the virtual IP and the tunnel to this host. Host-level actions (install, terminal, logs, upgrade) then apply to it.')"
              @click="askSwitch(peer)">
              <icon name="exchange-alt" class="mr-1" />{{ $i18n.t('Make active') }}
            </b-button>
          </b-td>
        </b-tr>
      </b-tbody>
    </b-table-simple>
    <b-card-body v-if="!haPeersAlive.length" class="pt-2">
      <b-alert show variant="warning" class="mb-0 py-1 small">
        {{ $i18n.t('No backup host is reporting to the master: a failure of this host would interrupt the service.') }}
      </b-alert>
    </b-card-body>
  </b-card>
</template>
<script>
import { inject } from '@vue/composition-api'
import { formatDate } from '../_composables/useRemoteStatus'

export const setup = () => {
  const remote = inject('connectorRemote')
  const { settingsLocation } = inject('connectorTabs')
  return {
    ...remote,
    formatDate,
    settingsLocation
  }
}

// @vue/component
export default {
  name: 'the-high-availability',
  inheritAttrs: false,
  setup
}
</script>
