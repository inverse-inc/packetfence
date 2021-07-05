<template>
  <span>
    <div class="pf-counter-over-chart" v-if="counter">
      <div :id="id" class="display-4"></div>
      <div class="pf-counter-chart-title">{{ chart.title }}</div>
    </div>
    <div
      :data-netdata="chart.metric"
      :data-host="host"
      :data-title="title"
      :data-chart-library="chart.library"
      :data-height="chart.height"
      v-bind="attrs"
      role="application"></div>
  </span>
</template>

<script>
export const modes = {
  LOCAL: 'local', // no_cluster
  SINGLE: 'single', // graph_per_host
  COMBINED: 'combined' // default
}

export const libs = {
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

export default {
  name: 'chart',
  inheritAttrs: false,
  props: {
    storeName: {
      type: String,
      default: null,
      required: true
    },
    definition: {
      type: Object,
      default: () => {},
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
  },
  data () {
    return {
      counter: false,
      chart: {
        title: 'Untitled',
        metric: null,
        library: libs.DYGRPAH,
        mode: modes.COMBINED,
        height: '225px',
        params: {}
      },
      attrs: {
        'data-colors': palettes[0],
        'data-before': 0,
        'data-after': -7200,
        'data-hide-missing': 'true'
      },
      hosts: []
    }
  },
  computed: {
    id () {
      return (this.chart.metric + this.host).replace(/\./g, '_')
    },
    title () {
      if (this.chart.mode === modes.SINGLE) {
        return [this.chart.title, this.$i18n.t('on'), this.host.replace(/^\/netdata\//, '')].join(' ')
      } else {
        return this.chart.title
      }
    }
  },
  created () {
    const { params } = this.definition
    this.chart = { ...this.chart, ...this.definition }
    this.attrs = { ...this.attrs, ...this.$attrs }
    if (params) {
      Object.keys(params).forEach(key => {
        this.attrs['data-' + key.replace(/_/g, '-')] = params[key]
      })
    }
    if (this.definition.library === libs.DYGRAPH_COUNTER) {
      this.chart.library = libs.DYGRPAH
      this.chart.height = '100px'
      this.counter = true
      this.attrs['data-show-value-of-gauge-at'] = this.id
    }
  }
}
</script>
