<template>
  <b-card no-body>
    <b-card-header>
      <h5 class="mb-0">PacketFence</h5>
      <p class="mb-0"><mac>{{ version }}</mac></p>
    </b-card-header>
  </b-card>
</template>

<script>
import { computed } from '@vue/composition-api'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const version = computed(() => $store.getters['system/version'])

  return {
    version
  }
}

// @vue/component
export default {
  name: 'tooltip-packetfence',
  setup
}
</script>
