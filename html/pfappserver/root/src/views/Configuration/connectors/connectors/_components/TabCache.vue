<template>
  <b-tab :title="$i18n.t('RADIUS Cache')" lazy>
    <the-cache v-if="isConnected" :id="id" />
    <b-card v-else class="mb-3" bg-variant="light">
      <h6 class="mb-0">{{ $i18n.t('RADIUS Cache') }}</h6>
      <small class="text-muted">{{ $i18n.t('The cache of the remote connector is managed while the tunnel is connected.') }}</small>
    </b-card>
  </b-tab>
</template>
<script>
import { inject } from '@vue/composition-api'
import TheCache from './TheCache'

const components = {
  TheCache
}

export const props = {
  id: {
    type: String
  }
}

export const setup = () => {
  const { isConnected } = inject('connectorRemote')
  return {
    isConnected
  }
}

// @vue/component
export default {
  name: 'tab-cache',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
