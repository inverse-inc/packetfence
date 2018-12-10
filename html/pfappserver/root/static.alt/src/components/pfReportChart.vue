<!--
 * Component to draw plotly charts.
 *
 * https://plot.ly/javascript/reference/
 * https://plot.ly/javascript/plotlyjs-function-reference/
 -->
<template>
  <b-container id="pfReportChart" fluid>
    <b-row class="mb-3" align-h="between" align-v="center">
      <b-col cols="auto" class="text-left" v-if="range">
        <b-form inline>
          <b-btn variant="link" id="periods">
            <icon name="stopwatch"></icon>
          </b-btn>
          <b-popover class="popover-full" target="periods" triggers="click focus blur" placement="bottomright" container="pfReportChart" :show.sync="showPeriod">
            <b-form-row class="align-items-center">
              <div class="mx-1">{{ $t('Previous') }}</div>
                <b-button-group vrel="periodButtonGroup">
                  <b-button variant="light" @click="setRangeByPeriod(60 * 30)" v-b-tooltip.hover.bottom.d300 :title="$t('30 minutes')">30m</b-button>
                  <b-button variant="light" @click="setRangeByPeriod(60 * 60)" v-b-tooltip.hover.bottom.d300 :title="$t('1 hour')">1h</b-button>
                  <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 6)" v-b-tooltip.hover.bottom.d300 :title="$t('6 hours')">6h</b-button>
                  <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 12)" v-b-tooltip.hover.bottom.d300 :title="$t('12 hours')">12h</b-button>
                  <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 24)" v-b-tooltip.hover.bottom.d300 :title="$t('1 day')">1D</b-button>
                  <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 24 * 7)" v-b-tooltip.hover.bottom.d300 :title="$t('1 week')">1W</b-button>
                  <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 24 * 14)" v-b-tooltip.hover.bottom.d300 :title="$t('2 weeks')">2W</b-button>
                  <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 24 * 28)" v-b-tooltip.hover.bottom.d300 :title="$t('1 month')">1M</b-button>
                  <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 24 * 28 * 2)" v-b-tooltip.hover.bottom.d300 :title="$t('2 months')">2M</b-button>
                  <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 24 * 28 * 6)" v-b-tooltip.hover.bottom.d300 :title="$t('6 months')">6M</b-button>
                  <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 24 * 365)" v-b-tooltip.hover.bottom.d300 :title="$t('1 year')">1Y</b-button>
                </b-button-group>
            </b-form-row>
          </b-popover>
          <pf-form-datetime v-model="datetimeStart" :max="maxStartDatetime" :prepend-text="$t('Start')" class="mr-3" :disabled="isLoading"></pf-form-datetime>
          <pf-form-datetime v-model="datetimeEnd" :min="minEndDatetime" :prepend-text="$t('End')" class="mr-3" :disabled="isLoading"></pf-form-datetime>
        </b-form>
      </b-col>
      <b-col cols="auto" class="mr-auto"></b-col>
      <b-col cols="auto">
        <b-input-group :prepend="$t('Limit chart')" class="mr-3">
          <b-form-select class="pr-4" v-model="chartSizeLimit" :options="[5,10,25,50,100]" :disabled="isLoading" @input="onChartSizeChange" />
        </b-input-group>
      </b-col>
    </b-row>
    <b-row>
      <b-col cols="12">
        <div ref="plotly"></div>
      </b-col>
    </b-row>
  </b-container>
</template>

<script>
import Plotly from 'plotly.js'
import { format, subSeconds } from 'date-fns'
import {
  pfReportChartColorsFull as colorsFull,
  pfReportChartColorsNull as colorsNull
} from '@/globals/pfReports'
import pfFormDatetime from '@/components/pfFormDatetime'

export default {
  name: 'pf-report-chart',
  components: {
    'pf-form-datetime': pfFormDatetime
  },
  props: {
    isLoading: {
      type: Boolean,
      default: false
    },
    items: {
      type: Array
    },
    report: {
      type: Object
    },
    range: {
      type: Boolean,
      default: false
    },
    datetimeStart: {
      type: String
    },
    datetimeEnd: {
      type: String
    }
  },
  data () {
    return {
      chartSizeLimit: 25,
      showPeriod: false,
      maxStartDatetime: '9999-12-12 23:59:59',
      minEndDatetime: '0000-00-00 00:00:00',
      data: {
        type: Object,
        default: {
          values: [],
          labels: [],
          options: {}
        }
      }
    }
  },
  computed: {
  },
  methods: {
    queueRender () {
      // buffer async calls to render
      if (this.timeoutRender) clearTimeout(this.timeoutRender)
      this.timeoutRender = setTimeout(this.render, 100)
    },
    render () {
      if (!this.$refs.plotly) return
      // dereference items, deep copy
      const itemsString = JSON.stringify(this.items)
      let values = this.report.chart.values(JSON.parse(itemsString))
      let labels = this.report.chart.labels(JSON.parse(itemsString))
      // dereference colors, deep copy
      let colors = JSON.parse(JSON.stringify(colorsFull))
      if (values.length === 0) {
        // no data
        colors = colorsNull
        values = [100]
        labels = [this.$i18n.t('No Data')]
      } else {
        // zip together then sort
        let zip = values.map((e, i) => [e, labels[i]]).sort((a, b) => (a[0] === b[0]) ? 0 : (a[0] > b[0]) ? -1 : 1)
        // truncate chart size limit
        if (zip.length > this.chartSizeLimit) {
          let other = zip.slice(this.chartSizeLimit).map(zip => zip[0])
          zip = zip.slice(0, this.chartSizeLimit)
          // push [sum(val), 'Other']
          zip.push([other.reduce((sum, val) => sum + val), this.$i18n.t('Other')])
          // "Paint It Black" - Rolling Stones
          colors[this.chartSizeLimit] = '#000000'
          // unzip
          values = zip.map(zip => zip[0])
          labels = zip.map(zip => zip[1])
        }
      }
      let options = this.report.chart.options
      if (!options.marker) options.marker = {}
      options.marker = Object.assign(options.marker, { colors: colors })
      this.data = [Object.assign({
        values: values,
        labels: labels
      }, options)]
      Plotly.react(this.$refs.plotly, this.data, this.report.chart.layout, { displayModeBar: true, scrollZoom: true, displaylogo: false, showLink: false })
    },
    getWindowWidth (event) {
      const width = document.documentElement.clientWidth
      if (event && width !== this.windowWidth) {
        this.queueRender()
      }
      this.windowWidth = width
    },
    getWindowHeight (event) {
      const height = document.documentElement.clientHeight
      if (event && height !== this.windowHeight) {
        this.queueRender()
      }
      this.windowHeight = height
    },
    onChartSizeChange (chartSizeLimit) {
      this.chartSizeLimit = chartSizeLimit
      this.queueRender()
    },
    setRangeByPeriod (period) {
      this.showPeriod = false
      this.$emit('changeDatetimeEnd', format(new Date(), 'YYYY-MM-DD HH:mm:ss'))
      this.$emit('changeDatetimeStart', format(subSeconds(new Date(), period), 'YYYY-MM-DD HH:mm:ss'))
    }
  },
  mounted () {
    this.$nextTick(() => {
      window.addEventListener('resize', this.getWindowWidth)
      window.addEventListener('resize', this.getWindowHeight)
      this.getWindowWidth()
      this.getWindowHeight()
    })
  },
  watch: {
    items: {
      handler: function (a, b) {
        this.queueRender()
      },
      immediate: true,
      deep: true
    },
    report: {
      handler: function (a, b) {
        if (JSON.stringify(a) !== JSON.stringify(b)) {
          this.queueRender()
        }
      },
      immediate: true,
      deep: true
    },
    datetimeStart (a, b) {
      if (a !== b) {
        this.$emit('changeDatetimeStart', a)
        this.minEndDatetime = a
      }
    },
    datetimeEnd (a, b) {
      if (a !== b) {
        this.$emit('changeDatetimeEnd', a)
        this.maxStartDatetime = a
      }
    }
  },
  beforeDestroy () {
    if (this.timeoutRender) {
      clearTimeout(this.timeoutRender)
    }
    window.removeEventListener('resize', this.getWindowWidth)
    window.removeEventListener('resize', this.getWindowHeight)
  }
}
</script>

<style>
/**
 * Don't limit the size of the popover
 */
#pfReportChart .popover {
  max-width: none;
}
</style>

<style lang="scss" scoped>
@import "../../node_modules/bootstrap/scss/functions";
@import "../styles/variables";

/**
 * Disable selection when double-clicking legend
 */
.plotly * {
  user-select: none;
}

/**
 * Add btn-primary color(s) on hover
 */
.btn-group[rel=periodButtonGroup] button:hover {
  border-color: $input-btn-hover-bg-color;
  background-color: $input-btn-hover-bg-color;
  color: $input-btn-hover-text-color;
}

</style>
