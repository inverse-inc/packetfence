<template>
  <span v-if="isLive" class="connector-header">
    <b-badge class="ml-2" :variant="isConnected ? 'success' : (status ? 'danger' : 'secondary')"
      v-b-tooltip.hover.bottom.d300 :title="tunnelTooltip">
      <icon name="circle" scale="0.5" class="mr-1" />{{ tunnelLabel }}
    </b-badge>
    <b-badge v-if="status && status.upgrade_available" class="ml-1" variant="warning">
      {{ $i18n.t('Update available') }}
    </b-badge>
    <span class="float-right mr-2">
      <b-button size="sm" variant="outline-secondary" class="mr-1" :disabled="isLoading" @click="refresh"
        v-b-tooltip.hover.bottom.d300 :title="$i18n.t('Refresh live data (every 30 seconds)')">
        <icon name="sync" :spin="isLoading" />
      </b-button>
      <b-dropdown size="sm" variant="outline-secondary" right no-caret
        v-b-tooltip.hover.bottom.d300 :title="$i18n.t('Troubleshoot: terminal, logs, DNS lookup, restart')">
        <template #button-content><icon name="tools" /></template>
        <b-dropdown-item v-if="canUpdate" :disabled="!isConnected || !isTerminalEnabled || isTerminalLoading" @click="openTerminal">
          <icon name="terminal" class="mr-1" />{{ $i18n.t('Open remote terminal...') }}
        </b-dropdown-item>
        <b-dropdown-item :disabled="!isConnected || !logFiles.length" @click="goToTab('troubleshooting')">
          <icon name="scroll" class="mr-1" />{{ $i18n.t('View logs') }}
        </b-dropdown-item>
        <b-dropdown-item :disabled="!dnsConnectors.length" @click="goToDns">
          <icon name="stethoscope" class="mr-1" />{{ $i18n.t('DNS lookup') }}
        </b-dropdown-item>
        <template v-if="canUpdate">
          <b-dropdown-divider />
          <b-dropdown-item variant="danger" :disabled="!isConnected || isRestarting" @click="showRestartModal = true">
            <icon name="redo" class="mr-1" />{{ $i18n.t('Restart connector...') }}
          </b-dropdown-item>
        </template>
      </b-dropdown>
    </span>
    <div class="small text-muted mt-1">
      <span class="mr-3" :class="{ 'connector-header-stale': !isConnected }"
        v-b-tooltip.hover.bottom.d300 :title="isConnected ? '' : $i18n.t('Last reported address, may be stale while the tunnel is down.')">
        {{ $i18n.t('Host IP(s)') }}
        <span class="text-monospace text-body">{{ hostIps || '-' }}</span>
      </span>
      <span class="mr-3">
        {{ $i18n.t('Version') }}
        <span class="text-body">{{ (system && system.version) || '-' }}</span>
      </span>
      <span class="mr-3">
        {{ $i18n.t('Hostname') }}
        <span class="text-body">{{ (system && system.hostname) || '-' }}</span>
      </span>
      <span v-if="lastRefresh">
        {{ $i18n.t('Updated') }} <timeago :datetime="lastRefresh" :auto-update="60" :locale="$i18n.locale" />
      </span>
    </div>
  </span>
</template>
<script>
import { computed, inject } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const props = {
  id: {
    type: String
  },
  isNew: {
    type: Boolean
  },
  isClone: {
    type: Boolean
  }
}

export const setup = props => {
  const remote = inject('connectorRemote')
  const { goToTab, goToDns } = inject('connectorTabs')
  const {
    canRead,
    status,
    isConnected
  } = remote

  const isLive = computed(() => !!props.id && !props.isNew && !props.isClone && canRead.value)

  const tunnelLabel = computed(() => {
    if (!status.value)
      return i18n.t('Status unavailable')
    return isConnected.value ? i18n.t('Tunnel connected') : i18n.t('Tunnel disconnected')
  })

  const tunnelTooltip = computed(() => {
    if (!status.value)
      return i18n.t('The remote connector status could not be fetched.')
    return isConnected.value
      ? i18n.t('The connector tunnel to the pfconnector server is active.')
      : i18n.t('No active tunnel from this connector to the pfconnector server.')
  })

  const hostIps = computed(() => {
    const { remote_ips: ips = [] } = status.value || {}
    return (ips || []).join(', ')
  })

  return {
    ...remote,
    isLive,
    tunnelLabel,
    tunnelTooltip,
    hostIps,
    goToTab,
    goToDns
  }
}

// @vue/component
export default {
  name: 'the-header',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
.connector-header {
  .connector-header-stale {
    opacity: 0.6;
  }
}
</style>
