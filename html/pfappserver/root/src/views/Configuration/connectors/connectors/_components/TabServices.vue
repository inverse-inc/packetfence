<template>
  <b-tab :title="$i18n.t('Services')" lazy>
    <!-- full width: the cards list the services with their actions -->
    <the-connector-services v-if="containerServices" class="mb-3" />
    <b-card v-else-if="isConnected" class="mb-3">
      <h6>{{ $i18n.t('Connector Services') }}</h6>
      <p class="small text-muted mb-0">{{ $i18n.t('This connector does not report the state of its services (older connector package).') }}</p>
    </b-card>
    <the-ntlm-services v-if="hostPackages" class="mb-3" />
    <b-card v-else class="mb-3">
      <h6>{{ $i18n.t('NTLM Authentication Services') }}</h6>
      <p class="small text-muted mb-0">
        {{ isConnected ? $i18n.t('This connector does not report the state of its host packages (older connector package).') : $i18n.t('The state of the host packages is reported while the tunnel is connected.') }}
      </p>
    </b-card>

    <b-card v-if="canUpdate" border-variant="danger">
      <b-row align-v="center">
        <b-col>
          <h6 class="mb-0">{{ $i18n.t('Restart connector') }}</h6>
          <small class="text-muted">{{ $i18n.t('The whole remote connector will be restarted (RADIUS, Fingerbank collector and tunnel included). Network activity through this connector will be interrupted for a short period.') }}</small>
        </b-col>
        <b-col cols="auto">
          <b-button variant="outline-danger" :disabled="!isConnected || isRestarting" @click="showRestartModal = true">
            <icon name="redo" class="mr-1" />{{ $i18n.t('Restart...') }}
          </b-button>
        </b-col>
      </b-row>
    </b-card>
  </b-tab>
</template>
<script>
import { inject } from '@vue/composition-api'
import TheConnectorServices from './TheConnectorServices'
import TheNtlmServices from './TheNtlmServices'

const components = {
  TheConnectorServices,
  TheNtlmServices
}

export const props = {
  id: {
    type: String
  }
}

export const setup = () => {
  const remote = inject('connectorRemote')

  return {
    ...remote
  }
}

// @vue/component
export default {
  name: 'tab-services',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
