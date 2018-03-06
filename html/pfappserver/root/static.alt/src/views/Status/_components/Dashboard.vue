<template>
    <b-container fluid>
    <b-row>
        <b-col class="mt-3" :cols="chart.cols" v-for="chart in charts" :key="chart.id">
            <div :data-netdata="chart.name"
                 :data-title="chart.title"
                 :data-chart-library="chart.library"
                 role="application"></div>
        </b-col>
        <b-col cols="3">
            <b-alert show variant="secondary" class="mt-3">
            <b-form-select v-model="new_chart.id" class="mb-1">
                <option value="null" disabled>Select a chart</option>
                <optgroup v-for="module in all_modules" :label="module" :key="module">
                    <option v-for="chart in moduleCharts(module)" :key="chart.id" :value="chart.id">{{ chart.name }}</option>
                </optgroup>
            </b-form-select>
            <b-form-select v-model="new_chart.library" class="mb-1">
                <option :value="null" disabled>Select a library</option>
                <option value="dygraph">dygraph</option>
                <option value="gauge">gauge</option>
                <option value="easypiechart">easypiechart</option>
                <option value="peity">peity</option>
            </b-form-select>
            <b-form-select v-model="new_chart.cols" class="mb-3">
                <option :value="null" disabled>Select a number of columns</option>
                <option :value="col" v-for="col in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]" :key="col">{{ col }}</option>
            </b-form-select>
            <b-button @click="addChart(new_chart)" :disabled="!new_chart_valid">Add chart</b-button>
            </b-alert>
        </b-col>
    </b-row>
    </b-container>
</template>

<script>
import Vue from 'vue'

export default {
  name: 'Dashboard',
  props: {
  },
  data () {
    return {
      new_chart: {
        id: null,
        cols: 6,
        library: 'dygraph'
      }
    }
  },
  computed: {
    charts () {
      return this.$store.state.$_status.charts
    },
    all_modules () {
      return this.$store.getters['$_status/allModules']
    },
    chart_dimensions () {
      return Object.keys(this.chart.dimensions).join('|')
    },
    new_chart_valid () {
      return this.new_chart.value !== null && this.new_chart.cols > 0 && this.new_chart.library !== null
    }
  },
  methods: {
    moduleCharts (module) {
      let charts = []
      for (var chart of this.$store.state.$_status.allCharts) {
        if ((chart.module && chart.module === module) || (!chart.module && module === 'other')) {
          charts.push(chart)
        }
      }
      return charts
    },
    addChart (options) {
      let definition = this.$store.state.$_status.allCharts.find(c => c.id === options.id)
      let chart = Object.assign(definition, options)
      this.$store.dispatch('$_status/addChart', chart)
      Vue.nextTick(() => {
        window.NETDATA.parseDom()
      })
    }
  },
  created () {
  },
  mounted () {
    let el = document.createElement('SCRIPT')
    window.netdataNoBootstrap = true
    // window.netdataTheme = 'slate' #272b30
    el.setAttribute('src', '//pf.inverse.ca:1443/netdata/127.0.0.1/dashboard.js')
    document.head.appendChild(el)

    this.$store.dispatch('$_status/allCharts', {})
  }
}
</script>

