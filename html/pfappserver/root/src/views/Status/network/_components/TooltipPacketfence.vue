<template>
  <b-card no-body ref="rootRef"
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

import { computed, ref, watch } from '@vue/composition-api'

const setup = (props, context) => {

  const { emit, root: { $store } = {} } = context

  const version = computed(() => $store.getters['system/version'])

  const rootRef = ref(null) // component ref
  watch([rootRef, version], () => {
    emit('bounds', rootRef.value.getBoundingClientRect())
  })

  return {
    rootRef,
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
