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
          </h6>
          <small v-if="lastRefresh" class="text-muted">{{ $i18n.t('Last refreshed') }}: {{ lastRefresh }}</small>
        </b-col>
        <b-col cols="auto">
          <b-button size="sm" variant="outline-secondary" class="mr-1" :disabled="isLoading" @click="refresh">
            <icon name="sync" :spin="isLoading" class="mr-1" />{{ $i18n.t('Refresh') }}
          </b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1"
            :disabled="!status || !status.connected || isTerminalLoading" @click="openTerminal">
            <icon name="terminal" class="mr-1" />{{ $i18n.t('Open Terminal') }}
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
          </b-col>
        </b-row>
      </template>
      <p v-else-if="!isLoading" class="text-muted mb-0">{{ $i18n.t('Status unavailable.') }}</p>
    </div>

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
import { onBeforeUnmount, onMounted, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import api from '../_api'

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
  const isTerminalLoading = ref(false)
  const showRestartModal = ref(false)
  const lastRefresh = ref(null)

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

  const openTerminal = () => {
    isTerminalLoading.value = true
    api.terminalSession(props.id).then(session => {
      return api.terminalAuthorize(props.id, session.uuid).then(() => {
        window.open(`/api/v1/terminal/${props.id}/`, '_blank')
      })
    }).catch(() => {
      $store.dispatch('notification/danger', { message: i18n.t('Unable to open a terminal on the remote connector.') })
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
    isTerminalLoading,
    showRestartModal,
    lastRefresh,
    refresh,
    restart,
    openTerminal,
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
  props,
  setup
}
</script>
