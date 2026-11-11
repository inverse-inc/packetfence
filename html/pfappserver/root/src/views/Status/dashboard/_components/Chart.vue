<template>
  <span>
    <div class="pf-counter-over-chart" v-if="counter">
      <div :id="id" class="display-4" />
    </div>
    <div
      :data-netdata="chart.metric"
      :data-host="host"
      :data-title="' '"
      :data-chart-library="chart.library"
      :data-height="chart.height"
      v-bind="attrs"
      role="application" />
  </span>
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

import { palettes } from '../../_config/palettes'
export { palettes }

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
