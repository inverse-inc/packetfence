<template>
  <base-chart-ringed ref="graphRef"
    class="m-3"
    :animate="animate"
    :dimensions="dimensions"
    :options="options"
    :items="items"
    :is-loading="isLoading"
    @device="toggleDevice"
    @host="toggleHost" />
</template>
<script>
import BaseChartRinged from './BaseChartRinged'
const components = {
  BaseChartRinged
}

const props = {
  animate: {
    type: Boolean
  },
  devices: {
    type: Array,
    default: () => ([])
  }
}

import { computed, nextTick, onBeforeUnmount, onMounted, ref, toRefs, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'

const setup = (props, context) => {

  const {
    devices
  } = toRefs(props)

  const { emit, refs, root: { $store } = {} } = context

  const isLoading = computed(() => $store.getters['$_fingerbank_communication/isLoading'])
  const tabular = computed(() => $store.getters['$_fingerbank_communication/tabular'])
  const items = computed(() => tabular.value.filter(item => devices.value.map(device => device.mac).indexOf(item.mac) > -1))

  const dimensions = ref({
    height: 100,
    width: 100,
    fit: 'max'
  })
  const options = ref({
    miniMapHeight: undefined,
    miniMapWidth: 200,
    miniMapPosition: 'top-left',
    minZoom: 0,
    maxZoom: 4,
    mouseWheelZoom: true,
    padding: 25
  })

  const graphRef = ref(null)
  let dimDebouncer
  const setDimensions = () => {
    if (!dimDebouncer)
      dimDebouncer = createDebouncer()
    dimDebouncer({
      handler: () => {
        // get width of svg container
        const { graphRef: { $el: { offsetWidth: width = 0 } = {} } = {} } = refs
        dimensions.value.width = width
        if (dimensions.value.fit === 'max')
          dimensions.value.height = width
        else {
          // get height of window document
          const documentHeight = Math.max(document.documentElement.clientHeight, window.innerHeight || 0)
          const { graphRef: { $el = {} } = {} } = refs
          const { top } = $el.getBoundingClientRect()
          const padding = 20 + 16 /* padding = 20, margin = 16 */
          let height = documentHeight - top - padding
          height = Math.max(height, width / 2) // minimum height of 1/2 width
          dimensions.value.height = height
        }
      },
      time: 100 // 100ms
    })
  }

  onMounted(() => { // DOM is ready
    watch([
      devices,
      items,
      () => dimensions.value.fit
    ], () => {
      nextTick(() => {
        setDimensions()
      })
    }, { deep: true, immediate: true })

    window.addEventListener('resize', setDimensions)
  })

  onBeforeUnmount(() => window.removeEventListener('resize', setDimensions))

  const toggleDevice = device => {
    //$store.dispatch('$_fingerbank_communication/toggleDevice', device)
    emit('device', device)
  }

  const toggleHost = host => {
    $store.dispatch('$_fingerbank_communication/toggleHost', host)
  }

  return {
    isLoading,
    items,
    graphRef,
    dimensions,
    options,
    toggleDevice,
    toggleHost,
  }
}

// @vue/component
export default {
  name: 'base-data-flow',
  components,
  props,
  setup
}
</script>