<template>
  <span>
    <div class="pf-counter-over-chart" v-if="counter">
      <div :id="id" class="display-4" />
      <div class="pf-counter-chart-title">{{ $i18n.t(chart.title) }}</div>
    </div>
    <div
      :data-netdata="chart.metric"
      :data-host="host"
      :data-title="title"
      :data-chart-library="chart.library"
      :data-height="chart.height"
      v-bind="attrs"
      role="application" />
  </span>
</template>

<script>
export const modes = {
  LOCAL: 'local', // no_cluster
  SINGLE: 'single', // graph_per_host
  COMBINED: 'combined' // default
}

export const libraries = {
  DYGRAPH: 'dygraph',
  DYGRAPH_COUNTER: 'dygraph-counter',
  EASYPIECHART: 'easypiechart',
  GAUGE: 'gauge',
  D3PIE: 'd3pie',
  SPARKLINE: 'sparkline',
  PEITY: 'peity'
}

export const palettes = [
  '#b2182b #d6604d #f4a582 #fddbc7 #f7f7f7 #d1e5f0 #92c5de #4393c3 #2166ac',
  '#01665e #35978f #80cdc1 #c7eae5 #f5f5f5 #f6e8c3 #dfc27d #bf812d #8c510a',
  '#762a83 #9970ab #c2a5cf #e7d4e8 #f7f7f7 #d9f0d3 #a6dba0 #5aae61 #1b7837'
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
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const {
    definition,
    host
  } = toRefs(props)

  const counter = ref(false)
  const chart = ref({
    title: i18n.t('Untitled'),
    metric: null,
    library: libraries.DYGRPAH,
    mode: modes.COMBINED,
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

  const title = computed(() => {
    if (chart.value.mode === modes.SINGLE)
      return [i18n.t(chart.value.title), i18n.t('on'), host.value.replace(/^\/netdata\//, '')].join(' ')
    else
      return i18n.t(chart.value.title)
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
    title,
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
