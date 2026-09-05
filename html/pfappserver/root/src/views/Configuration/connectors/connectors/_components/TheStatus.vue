<template>
  <div class="card mx-3 mb-3 bg-light">
    <div class="card-body">
      <b-row align-v="center" class="mb-2">
        <b-col>
          <h6 class="mb-0">
            {{ $i18n.t('Remote Connector Status') }}
            <b-badge v-if="status" :variant="status.connected ? 'success' : 'danger'" class="ml-2">
              {{ status.connected ? $i18n.t('Connected') : $i18n.t('Disconnected') }}
            </b-badge>
            <b-badge v-if="ha" :variant="haPeersAlive.length ? 'info' : 'warning'" class="ml-1"
              :title="haPeersAlive.length ? $i18n.t('High availability: {n} backup host(s) alive', { n: haPeersAlive.length }) : $i18n.t('High availability: no backup host reporting')">
              {{ $i18n.t('HA') }} · {{ ha.vip }}
            </b-badge>
          </h6>
          <small v-if="lastRefresh" class="text-muted">{{ $i18n.t('Last refreshed') }}: {{ lastRefresh }}</small>
        </b-col>
        <b-col cols="auto">
          <b-button size="sm" variant="outline-secondary" class="mr-1" :disabled="isLoading" @click="refresh">
            <icon name="sync" :spin="isLoading" class="mr-1" />{{ $i18n.t('Refresh') }}
          </b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1"
            :disabled="!status || !status.connected || isTerminalLoading || (status.system && status.system.terminal_enabled === false)"
            :title="(status && status.system && status.system.terminal_enabled === false) ? $i18n.t('The terminal is disabled on this connector (PFCONNECTOR_TERMINAL).') : ''"
            @click="openTerminal">
            <icon name="terminal" class="mr-1" />{{ $i18n.t('Open Terminal') }}
          </b-button>
          <b-button v-if="logFiles.length" size="sm" :variant="showLogs ? 'primary' : 'outline-primary'" class="mr-1"
            :disabled="!status || !status.connected"
            @click="showLogs = !showLogs">
            <icon name="scroll" class="mr-1" />{{ $i18n.t('View Logs') }}
          </b-button>
          <b-button v-if="status && status.upgrade_available" size="sm" variant="outline-warning" class="mr-1"
            :disabled="!status.connected || isUpgrading" @click="showUpgradeModal = true">
            <icon name="arrow-circle-up" class="mr-1" />{{ $i18n.t('Upgrade to {version}', { version: status.central_version }) }}
          </b-button>
          <b-button size="sm" variant="outline-danger"
            :disabled="!status || !status.connected || isRestarting" @click="showRestartModal = true">
            <icon name="redo" class="mr-1" />{{ $i18n.t('Restart') }}
          </b-button>
        </b-col>
      </b-row>

      <b-alert :show="errors.length > 0" variant="warning" class="mb-2">
        <div v-for="(error, index) in errors" :key="index">{{ error }}</div>
      </b-alert>

      <template v-if="status">
        <b-row>
          <b-col md="6">
            <h6 class="text-secondary">{{ $i18n.t('Addresses') }}</h6>
            <p class="mb-2">
              <template v-if="status.remote_ips && status.remote_ips.length">
                <b-badge v-for="ip in status.remote_ips" :key="ip" variant="light" class="border mr-1 text-monospace">{{ ip }}</b-badge>
              </template>
              <span v-else class="text-muted">{{ $i18n.t('No IP address reported yet.') }}</span>
            </p>

            <h6 class="text-secondary">{{ $i18n.t('System') }}</h6>
            <b-table-simple v-if="status.system" small borderless class="mb-0">
              <b-tbody>
                <b-tr>
                  <b-td class="text-muted">{{ $i18n.t('Hostname') }}</b-td>
                  <b-td>{{ status.system.hostname }}</b-td>
                </b-tr>
                <b-tr>
                  <b-td class="text-muted">{{ $i18n.t('Version') }}</b-td>
                  <b-td>{{ status.system.version }}</b-td>
                </b-tr>
                <b-tr>
                  <b-td class="text-muted">{{ $i18n.t('Uptime') }}</b-td>
                  <b-td>{{ formatUptime(status.system.uptime_seconds) }}</b-td>
                </b-tr>
                <b-tr>
                  <b-td class="text-muted">{{ $i18n.t('Load (1/5/15m)') }}</b-td>
                  <b-td>{{ formatLoad(status.system.load1) }} / {{ formatLoad(status.system.load5) }} / {{ formatLoad(status.system.load15) }}</b-td>
                </b-tr>
                <b-tr>
                  <b-td class="text-muted">{{ $i18n.t('CPU') }}</b-td>
                  <b-td>{{ status.system.cpu_count }} {{ $i18n.t('cores') }}, {{ formatPercent(status.system.cpu_usage_percent) }}</b-td>
                </b-tr>
                <b-tr>
                  <b-td class="text-muted">{{ $i18n.t('Memory') }}</b-td>
                  <b-td>{{ formatBytes(status.system.mem_used) }} / {{ formatBytes(status.system.mem_total) }} ({{ formatPercent(status.system.mem_usage_percent) }})</b-td>
                </b-tr>
                <b-tr>
                  <b-td class="text-muted">{{ $i18n.t('Disk') }} /</b-td>
                  <b-td>{{ formatBytes(status.system.disk_used) }} / {{ formatBytes(status.system.disk_total) }} ({{ formatPercent(status.system.disk_usage_percent) }})</b-td>
                </b-tr>
              </b-tbody>
            </b-table-simple>
            <p v-else class="text-muted mb-0">{{ $i18n.t('System information unavailable.') }}</p>

            <template v-if="ha">
              <h6 class="text-secondary mt-3">{{ $i18n.t('High Availability') }}</h6>
              <p class="mb-1 small text-muted">
                {{ $i18n.t('Virtual IP {vip}: the host holding it runs the tunnel; the others report to it over the site network. Configure switches, portal redirection and DHCP relays with the virtual IP.', { vip: ha.vip }) }}
              </p>
              <b-table-simple small class="mb-0">
                <b-thead>
                  <b-tr>
                    <b-th>{{ $i18n.t('Host') }}</b-th>
                    <b-th>{{ $i18n.t('Role') }}</b-th>
                    <b-th>{{ $i18n.t('Version') }}</b-th>
                    <b-th>{{ $i18n.t('Since / Last seen') }}</b-th>
                    <b-th>{{ $i18n.t('Status') }}</b-th>
                  </b-tr>
                </b-thead>
                <b-tbody>
                  <b-tr>
                    <b-td class="text-monospace">{{ ha.hostname || status.system.hostname }}</b-td>
                    <b-td>{{ $i18n.t('master') }}</b-td>
                    <b-td>{{ status.system.version }}</b-td>
                    <b-td>{{ formatDate(ha.since) }}</b-td>
                    <b-td><b-badge variant="success">{{ $i18n.t('holds the VIP') }}</b-badge></b-td>
                  </b-tr>
                  <b-tr v-for="peer in ha.peers" :key="peer.hostname">
                    <b-td class="text-monospace">{{ peer.hostname }} <small class="text-muted">{{ peer.address }}</small></b-td>
                    <b-td>{{ $i18n.t(peer.state || 'backup') }}<template v-if="peer.priority"> <small class="text-muted">({{ $i18n.t('priority') }} {{ peer.priority }})</small></template></b-td>
                    <b-td>{{ peer.version }}</b-td>
                    <b-td>{{ formatDate(peer.last_seen) }}</b-td>
                    <b-td>
                      <b-badge :variant="peer.alive ? 'success' : 'danger'">{{ peer.alive ? $i18n.t('alive') : $i18n.t('not reporting') }}</b-badge>
                    </b-td>
                  </b-tr>
                </b-tbody>
              </b-table-simple>
              <b-alert :show="!haPeersAlive.length" variant="warning" class="mt-2 mb-0 py-1 small">
                {{ $i18n.t('No backup host is reporting to the master: a failure of this host would interrupt the service.') }}
              </b-alert>
            </template>
          </b-col>
          <b-col md="6">
            <h6 class="text-secondary">{{ $i18n.t('Static Connections') }}</h6>
            <b-table-simple v-if="status.static_connections && status.static_connections.length" small class="mb-0">
              <b-thead>
                <b-tr>
                  <b-th>{{ $i18n.t('Port') }}</b-th>
                  <b-th>{{ $i18n.t('Protocol') }}</b-th>
                  <b-th>{{ $i18n.t('Target') }}</b-th>
                  <b-th>{{ $i18n.t('Status') }}</b-th>
                </b-tr>
              </b-thead>
              <b-tbody>
                <b-tr v-for="(connection, index) in status.static_connections" :key="index">
                  <b-td class="text-monospace">{{ connection.local_port }}</b-td>
                  <b-td>{{ connection.local_proto }}</b-td>
                  <b-td class="text-monospace">{{ connection.remote_host }}:{{ connection.remote_port }}</b-td>
                  <b-td>
                    <b-badge :variant="connection.bound ? 'success' : 'danger'">
                      {{ connection.bound ? $i18n.t('open') : $i18n.t('closed') }}
                    </b-badge>
                  </b-td>
                </b-tr>
              </b-tbody>
            </b-table-simple>
            <p v-else class="text-muted mb-0">{{ $i18n.t('No static connection configured for this connector.') }}</p>

            <h6 class="text-secondary mt-3">{{ $i18n.t('Dynamic Connections') }}</h6>
            <b-table-simple v-if="status.bound_remotes && status.bound_remotes.length" small class="mb-0">
              <b-thead>
                <b-tr>
                  <b-th>{{ $i18n.t('Server Port') }}</b-th>
                  <b-th>{{ $i18n.t('Protocol') }}</b-th>
                  <b-th>{{ $i18n.t('Target') }}</b-th>
                </b-tr>
              </b-thead>
              <b-tbody>
                <b-tr v-for="(remote, index) in status.bound_remotes" :key="index">
                  <b-td class="text-monospace">{{ remote.local_host }}:{{ remote.local_port }}</b-td>
                  <b-td>{{ remote.local_proto }}</b-td>
                  <b-td class="text-monospace">{{ remote.remote_host }}:{{ remote.remote_port }}</b-td>
                </b-tr>
              </b-tbody>
            </b-table-simple>
            <p v-else class="text-muted mb-0">{{ $i18n.t('No dynamic connection currently bound for this connector.') }}</p>
          </b-col>
        </b-row>

        <b-row v-if="siteNetwork" class="mt-3">
          <b-col md="6">
            <h6 class="text-secondary">{{ $i18n.t('Site networking: VLAN interfaces') }}</h6>
            <b-table-simple v-if="siteNetwork.interfaces && siteNetwork.interfaces.length" small class="mb-0">
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
                    <small v-if="iface.error" class="d-block text-danger">{{ iface.error }}</small>
                  </b-td>
                </b-tr>
              </b-tbody>
            </b-table-simple>
            <p v-else class="text-muted mb-0">{{ $i18n.t('No VLAN interface configured for this connector.') }}</p>
          </b-col>
          <b-col md="6">
            <h6 class="text-secondary">{{ $i18n.t('Site networking: static routes') }}</h6>
            <b-table-simple v-if="siteNetwork.routes && siteNetwork.routes.length" small class="mb-0">
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
                    <small v-if="route.error" class="d-block text-danger">{{ route.error }}</small>
                  </b-td>
                </b-tr>
              </b-tbody>
            </b-table-simple>
            <p v-else class="text-muted mb-0">{{ $i18n.t('No static route configured for this connector.') }}</p>
          </b-col>
        </b-row>

        <b-row v-if="dhcpRelay.length || dnsServer.length" class="mt-3">
          <b-col v-if="dnsServer.length" md="5">
            <h6 class="text-secondary">{{ $i18n.t('Site networking: captive DNS') }}</h6>
            <b-table-simple small class="mb-0">
              <b-thead>
                <b-tr>
                  <b-th>{{ $i18n.t('Interface') }}</b-th>
                  <b-th>{{ $i18n.t('State') }}</b-th>
                  <b-th>{{ $i18n.t('Queries') }}</b-th>
                </b-tr>
              </b-thead>
              <b-tbody>
                <b-tr v-for="srv in dnsServer" :key="srv.interface">
                  <b-td class="text-monospace">{{ srv.interface }} ({{ srv.ip }})</b-td>
                  <b-td>
                    <b-badge :variant="srv.state === 'listening' ? 'success' : 'danger'" :title="srv.error || ''">{{ srv.state }}</b-badge>
                    <small v-if="srv.error" class="d-block text-danger">{{ srv.error }}</small>
                  </b-td>
                  <b-td>{{ srv.queries }}</b-td>
                </b-tr>
              </b-tbody>
            </b-table-simple>
          </b-col>
          <b-col v-if="dhcpRelay.length">
            <h6 class="text-secondary">{{ $i18n.t('Site networking: DHCP relay') }}</h6>
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
                    <b-badge :variant="relay.state === 'listening' ? 'success' : 'danger'" :title="relay.error || relay.last_error || ''">{{ relay.state }}</b-badge>
                    <small v-if="relay.error || relay.last_error" class="d-block text-danger">{{ relay.error || relay.last_error }}</small>
                  </b-td>
                  <b-td>{{ relay.requests }}</b-td>
                  <b-td>{{ relay.replies }}</b-td>
                  <b-td>{{ relay.dropped }}</b-td>
                </b-tr>
              </b-tbody>
            </b-table-simple>
          </b-col>
        </b-row>
      </template>
      <p v-else-if="!isLoading" class="text-muted mb-0">{{ $i18n.t('Status unavailable.') }}</p>
    </div>

    <the-logs v-if="showLogs && logFiles.length" :id="id" :files="logFiles" />

    <b-modal v-model="showTerminalModal"
      :title="$i18n.t('Open Remote Terminal')"
      centered
    >
      <p>{{ $i18n.t('Enter the 6-digit code from the authenticator enrolled on this connector. The code is validated by the remote connector itself.') }}</p>
      <b-form @submit.prevent="authorizeTerminal">
        <b-form-input v-model="terminalCode" class="text-monospace"
          autofocus autocomplete="one-time-code" inputmode="numeric" maxlength="6" placeholder="123456" />
      </b-form>
      <template #modal-footer="{ hide }">
        <b-button variant="secondary" @click="hide()">{{ $i18n.t('Cancel') }}</b-button>
        <b-button variant="primary" :disabled="isTerminalLoading || terminalCode.length !== 6" @click="authorizeTerminal">
          {{ $i18n.t('Open Terminal') }}
        </b-button>
      </template>
    </b-modal>

    <b-modal v-model="showUpgradeModal"
      :title="$i18n.t('Upgrade Remote Connector')"
      centered
    >
      <p>{{ $i18n.t('The remote connector will point its PacketFence package repository at version {version}, upgrade its packetfence-pfconnector-remote package and restart. Network activity through this connector will be interrupted for a short period. Continue?', { version: status ? status.central_version : '' }) }}</p>
      <template #modal-footer="{ hide }">
        <b-button variant="secondary" @click="hide()">{{ $i18n.t('Cancel') }}</b-button>
        <b-button variant="warning" :disabled="isUpgrading" @click="upgrade">{{ $i18n.t('Upgrade') }}</b-button>
      </template>
    </b-modal>

    <b-modal v-model="showRestartModal"
      :title="$i18n.t('Restart Remote Connector')"
      centered
    >
      <p>{{ $i18n.t('The whole remote connector will be restarted (RADIUS, Fingerbank collector and tunnel included). Network activity through this connector will be interrupted for a short period. Continue?') }}</p>
      <template #modal-footer="{ hide }">
        <b-button variant="secondary" @click="hide()">{{ $i18n.t('Cancel') }}</b-button>
        <b-button variant="danger" :disabled="isRestarting" @click="restart">{{ $i18n.t('Restart') }}</b-button>
      </template>
    </b-modal>
  </div>
</template>
<script>
import { computed, onBeforeUnmount, onMounted, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import api from '../_api'
import TheLogs from './TheLogs'

export const props = {
  id: {
    type: String
  }
}

export const setup = (props, context) => {
  const { root: { $store } = {} } = context

  const status = ref(null)
  const errors = ref([])
  const isLoading = ref(false)
  const isRestarting = ref(false)
  const isUpgrading = ref(false)
  const showUpgradeModal = ref(false)
  const isTerminalLoading = ref(false)
  const showTerminalModal = ref(false)
  const terminalCode = ref('')
  const showRestartModal = ref(false)
  const lastRefresh = ref(null)
  const showLogs = ref(false)

  // The remote advertises its streamable logs in /system/info (log_files).
  // Connectors predating the feature (or with PFCONNECTOR_LOGS=false) omit
  // the field: no button, graceful degradation.
  const logFiles = computed(() => {
    const { system: { log_files: files } = {} } = status.value || {}
    return Array.isArray(files) ? files : []
  })

  // Result of the connector's last VLAN interface / static route reconcile
  // pass (/system/info site_network). Absent on connectors predating the
  // feature or before the first pass ran.
  const siteNetwork = computed(() => {
    const { system: { site_network: sn } = {} } = status.value || {}
    return sn || null
  })
  const dhcpRelay = computed(() => {
    const { system: { dhcp_relay: relay } = {} } = status.value || {}
    return Array.isArray(relay) ? relay : []
  })
  const dnsServer = computed(() => {
    const { system: { dns_server: srv } = {} } = status.value || {}
    return Array.isArray(srv) ? srv : []
  })
  const siteNetworkVariant = state => {
    switch (state) {
      case 'up':
      case 'applied':
        return 'success'
      case 'down':
        return 'warning'
      default:
        return 'danger'
    }
  }

  const refresh = () => {
    if (!props.id)
      return
    isLoading.value = true
    api.remoteStatus(props.id).then(response => {
      status.value = response
      errors.value = response.errors || []
      lastRefresh.value = (new Date()).toLocaleTimeString()
    }).catch(() => {
      errors.value = [i18n.t('Unable to fetch the remote connector status.')]
    }).finally(() => {
      isLoading.value = false
    })
  }

  const restart = () => {
    showRestartModal.value = false
    isRestarting.value = true
    api.remoteRestart(props.id).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Restart requested. The remote connector will reconnect shortly.') })
    }).catch(() => {
      $store.dispatch('notification/danger', { message: i18n.t('Unable to restart the remote connector.') })
    }).finally(() => {
      isRestarting.value = false
      setTimeout(refresh, 5000)
    })
  }

  const upgrade = () => {
    showUpgradeModal.value = false
    isUpgrading.value = true
    api.remoteUpgrade(props.id).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Upgrade started. The remote connector will restart and report its new version once done (see conf/upgrade.log on the connector host for details).') })
    }).catch(() => {
      $store.dispatch('notification/danger', { message: i18n.t('Unable to trigger the upgrade of the remote connector.') })
    }).finally(() => {
      isUpgrading.value = false
      setTimeout(refresh, 10000)
    })
  }

  const openTerminal = () => {
    const { system: { terminal_totp: totpRequired } = {} } = status.value || {}
    if (totpRequired === false) {
      // The remote reports TOTP disabled (PFCONNECTOR_TERMINAL_TOTP=false):
      // no code to prompt for. Enforcement stays on the remote either way.
      requestTerminal()
      return
    }
    terminalCode.value = ''
    showTerminalModal.value = true
  }

  const authorizeTerminal = () => {
    if (terminalCode.value.length !== 6)
      return
    requestTerminal(terminalCode.value)
  }

  const requestTerminal = code => {
    isTerminalLoading.value = true
    api.terminalSession(props.id).then(session => {
      return api.terminalAuthorize(props.id, session.uuid, code).then(() => {
        showTerminalModal.value = false
        window.open(`/api/v1/terminal/${props.id}/`, '_blank')
      })
    }).catch(error => {
      const { response: { data } = {} } = error || {}
      const detail = (typeof data === 'string' && data.trim()) ? ` (${data.trim()})` : ''
      $store.dispatch('notification/danger', { message: i18n.t('Unable to open a terminal on the remote connector.') + detail })
    }).finally(() => {
      isTerminalLoading.value = false
    })
  }

  const formatBytes = bytes => {
    if (!bytes && bytes !== 0)
      return '-'
    const units = ['B', 'KB', 'MB', 'GB', 'TB']
    let value = bytes
    let unit = 0
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024
      unit++
    }
    return `${value.toFixed(1)} ${units[unit]}`
  }

  const formatPercent = value => {
    if (!value && value !== 0)
      return '-'
    return `${value.toFixed(1)}%`
  }

  const formatLoad = value => {
    if (!value && value !== 0)
      return '-'
    return value.toFixed(2)
  }

  // HA state reported by the master (the only host with a tunnel); peers are
  // the backups heard through their LAN heartbeats.
  const ha = computed(() => {
    const { system: { ha: state } = {} } = status.value || {}
    return (state && state.enabled) ? state : null
  })
  const haPeersAlive = computed(() => ((ha.value && ha.value.peers) || []).filter(peer => peer.alive))

  const formatDate = value => {
    if (!value)
      return '-'
    const date = new Date(value)
    return isNaN(date.getTime()) ? '-' : date.toLocaleString()
  }

  const formatUptime = seconds => {
    if (!seconds && seconds !== 0)
      return '-'
    const days = Math.floor(seconds / 86400)
    const hours = Math.floor((seconds % 86400) / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    return `${days}d ${hours}h ${minutes}m`
  }

  let refreshInterval = null
  onMounted(() => {
    refresh()
    refreshInterval = setInterval(refresh, 30000)
  })
  onBeforeUnmount(() => {
    if (refreshInterval)
      clearInterval(refreshInterval)
  })

  return {
    status,
    errors,
    isLoading,
    isRestarting,
    isUpgrading,
    showUpgradeModal,
    isTerminalLoading,
    showTerminalModal,
    terminalCode,
    showRestartModal,
    lastRefresh,
    showLogs,
    logFiles,
    siteNetwork,
    siteNetworkVariant,
    dhcpRelay,
    dnsServer,
    refresh,
    restart,
    upgrade,
    openTerminal,
    authorizeTerminal,
    ha,
    haPeersAlive,
    formatDate,
    formatBytes,
    formatPercent,
    formatLoad,
    formatUptime
  }
}

// @vue/component
export default {
  name: 'the-status',
  inheritAttrs: false,
  components: {
    TheLogs
  },
  props,
  setup
}
</script>
