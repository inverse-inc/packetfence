<template>
  <b-card no-body
    class="tooltip-packetfence" :id="`tooltip-${id}`">
    <b-card-header class="p-2">
      <h5 class="mb-0">PacketFence</h5>
      <p class="mb-0"><mac>{{ version }}</mac></p>
    </b-card-header>
  </b-card>
</template>

<script>
const props = {
  id: {
    type: String
  }
}

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
  props,
  setup
}
</script>
