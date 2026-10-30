<template>
  <b-tab :title="$i18n.t('Troubleshooting')" lazy>
    <b-row>
      <b-col md="6" class="mb-3">
        <b-card class="h-100">
          <h6>{{ $i18n.t('Remote terminal') }}</h6>
          <p class="small text-muted">
            {{ $i18n.t('Opens a shell on the connector host in a new browser tab, through the tunnel.') }}
            <template v-if="system && system.terminal_totp !== false">{{ $i18n.t('The connector asks for the 6-digit code of the authenticator enrolled when it was installed, and validates it itself.') }}</template>
          </p>
          <b-button v-if="canUpdate" size="sm" variant="primary"
            :disabled="!isConnected || !isTerminalEnabled || isTerminalLoading" @click="openTerminal">
            <icon name="terminal" class="mr-1" />{{ $i18n.t('Open terminal...') }}
          </b-button>
          <div v-if="!canUpdate" class="small text-muted">{{ $i18n.t('Opening a terminal requires the right to update connectors.') }}</div>
          <div v-else-if="!isConnected" class="small text-muted mt-1">{{ $i18n.t('The tunnel is not connected.') }}</div>
          <div v-else-if="!isTerminalEnabled" class="small text-muted mt-1">{{ $i18n.t('The terminal is disabled on this connector (PFCONNECTOR_TERMINAL).') }}</div>
        </b-card>
      </b-col>
      <b-col md="6" class="mb-3">
        <b-card class="h-100">
          <h6>{{ $i18n.t('Connectivity checks') }}</h6>
          <p class="small text-muted">{{ $i18n.t('Resolve a name with one of the DNS servers behind this connector, through the tunnel.') }}</p>
          <b-button size="sm" variant="outline-primary" :disabled="!dnsConnectors.length" @click="goToDns">
            <icon name="stethoscope" class="mr-1" />{{ $i18n.t('DNS lookup through the tunnel') }}
          </b-button>
          <div v-if="!dnsConnectors.length" class="small text-muted mt-1">{{ $i18n.t('No DNS server is configured on this connector.') }}</div>
        </b-card>
      </b-col>
    </b-row>

    <b-card class="mb-3" no-body>
      <!-- the log inputs live inside the connector form: Enter must not submit it -->
      <div @keydown.enter="onLogsEnter">
        <the-logs v-if="isConnected && logFiles.length" :id="id" :files="logFiles" :file="logFile" :since="logSince" />
        <b-card-body v-else class="text-muted">
          {{ isConnected ? $i18n.t('This connector does not advertise any log file.') : $i18n.t('Logs are streamed while the tunnel is connected.') }}
        </b-card-body>
      </div>
    </b-card>

    <b-card v-if="recordingsAvailable" no-body>
      <the-terminal-recordings :id="id" />
    </b-card>
  </b-tab>
</template>
<script>
import { inject } from '@vue/composition-api'
import TheLogs from './TheLogs'
import TheTerminalRecordings from './TheTerminalRecordings'

const components = {
  TheLogs,
  TheTerminalRecordings
}

export const props = {
  id: {
    type: String
  }
}

export const setup = () => {
  const remote = inject('connectorRemote')
  const { goToDns, logFile, logSince } = inject('connectorTabs')

  const onLogsEnter = event => {
    if (event.target && event.target.tagName === 'INPUT')
      event.preventDefault()
  }

  return {
    ...remote,
    goToDns,
    logFile,
    logSince,
    onLogsEnter
  }
}

// @vue/component
export default {
  name: 'tab-troubleshooting',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
