/**
 * Component to draw plotly charts.
 * 
 * https://plot.ly/javascript/reference/
 * https://plot.ly/javascript/plotlyjs-function-reference/
 */
<template>
  <div ref="plotly"></div>
</template>

<script>
import Plotly from 'plotly.js'
import {
  pfReportChartColorsFull as colorsFull,
  pfReportChartColorsNull as colorsNull
} from '@/globals/pfReports'

export default {
  name: 'pf-report-chart',
  props: {
    items: {
      type: Array
    },
    report: {
      type: Object
    },
    data: {
      type: Object
    },
    layout: {
      type: Object
    },
    options: {
      type: Object
    }
  },
  computed: {
  },
  methods: {
    render () {
      if (!this.$refs.plotly) return
      // dereference items, permit modification
      let itemsString = JSON.stringify(this.items)
      let values = this.report.chart.values(JSON.parse(itemsString))
      let labels = this.report.chart.labels(JSON.parse(itemsString))
      let colors = colorsFull
      if (values.length === 0) {
        values = [100]
        labels = [this.$i18n.t('No Data')]
        colors = colorsNull
      }
      this.data = [Object.assign({
        values: values,
        labels: labels
      }, Object.assign({marker: { colors: colors }}, this.report.chart.options))]
      this.layout = {}
      this.options = {}
      Plotly.react(this.$refs.plotly, this.data, this.layout, this.options)
    }
  },
  mounted () {
  },
  created () {
  },
  watch: {
    items: {
      handler: function (a, b) {
        // buffer async calls to render
        if (this.timeoutRender) clearTimeout(this.timeoutRender)
        this.timeoutRender = setTimeout(this.render, 100)
      },
      immediate: true,
      deep: true
    },
    report: {
      handler: function (a, b) {
        // buffer async calls to render
        if (this.timeoutRender) clearTimeout(this.timeoutRender)
        this.timeoutRender = setTimeout(this.render, 100)
      },
      immediate: true,
      deep: true
    }
  }
}
</script>

