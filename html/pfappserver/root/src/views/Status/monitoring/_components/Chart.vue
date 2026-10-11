<template>
  <div
    :data-netdata="chart.metric"
    :data-host="host"
    :data-title="' '"
    :data-chart-library="chart.library"
    :data-height="chart.height"
    v-bind="attrs"
    role="application" />
</template>

<script>
export const libraries = {
  DYGRAPH: 'dygraph',
  DYGRAPH_COUNTER: 'dygraph-counter',
  EASYPIECHART: 'easypiechart',
  GAUGE: 'gauge',
  GOOGLE: 'google',
  D3PIE: 'd3pie',
  SPARKLINE: 'sparkline',
  PEITY: 'peity'
}

export const palettes = [
  // Qualitative palettes, readable on a white background (D3 category10,
  // ColorBrewer Dark2 and Set1 without its yellow)
  '#1f77b4 #d62728 #2ca02c #ff7f0e #9467bd #8c564b #e377c2 #7f7f7f #17becf #bcbd22',
  '#1b9e77 #d95f02 #7570b3 #e7298a #66a61e #e6ab02 #a6761d #666666',
  '#e41a1c #377eb8 #4daf4a #984ea3 #ff7f00 #a65628 #f781bf #999999'
]

const props = {
  definition: {
    type: Object,
    default: () => ({}),
    required: true
  },
  host: {
    type: String,
    default: '',
    required: true
  },
  cols: {
    type: Number,
    default: 6
  }
}

import { computed, ref, toRefs, watch } from '@vue/composition-api'

const setup = (props, context) => {

  const {
    definition,
    host
  } = toRefs(props)

  const counter = ref(false)
  const chart = ref({
    metric: null,
    library: libraries.DYGRPAH,
    height: '225px',
    params: {}
  })
  const attrs = ref({
    'data-colors': palettes[0],
    'data-before': 0,
    'data-after': -7200,
    'data-hide-missing': 'true'
  })

  const id = computed(() => {
    return (chart.value.metric + host.value).replace(/\./g, '_')
  })

  watch(definition, () => {
    const { params } = definition.value
    chart.value = { ...chart.value, ...definition.value }
    attrs.value = { ...attrs.value, ...context.attrs }
    if (params) {
      Object.keys(params).forEach(key => {
        attrs.value['data-' + key.replace(/_/g, '-')] = params[key]
      })
    }
    if (definition.value.library === libraries.DYGRAPH_COUNTER) {
      chart.value.library = libraries.DYGRAPH
      chart.value.height = '100px'
      counter.value = true
      attrs.value['data-show-value-of-gauge-at'] = id.value
    }
  }, { deep: true, immediate: true })

  return {
    chart,
    counter,
    id,
    attrs,
  }
}

// @vue/component
export default {
  name: 'chart',
  inheritAttrs: false,
  props,
  setup
}
</script>
