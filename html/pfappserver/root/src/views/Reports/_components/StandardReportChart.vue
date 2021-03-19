<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ $t('Standard Report') }} / {{ $t(report.category) }} / {{ $t(report.name) }}</h4>
    </b-card-header>

    <b-tabs ref="tabs" v-model="tabIndex" card>
      <b-tab v-for="tab in tabs" :key="tab.name" :title="tab.name" no-body>
        <template v-slot:title>
          {{ $t(tab.name) }}
        </template>
        <!-- TABS ARE ONLY VISUAL, NOTHING HERE... -->
      </b-tab>
    </b-tabs>

    <pf-report-chart v-if="report.chart"
      :report="report"
      :range="range"
      :items="items"
      :datetime-start="datetimeStart"
      :datetime-end="datetimeEnd"
      :is-loading="isLoading"
      @start="onChangeDatetimeStart"
      @end="onChangeDatetimeEnd"
      class="mt-3"
    ></pf-report-chart>

    <div class="card-body">
      <b-table :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc" :sort-compare="sortCompare"
        @sort-changed="onSortingChanged" show-empty responsive hover sort-icon-left striped v-model="tableValues">
        <template v-slot:empty>
          <pf-empty-table :isLoading="isLoading">{{ $t('No data found') }}</pf-empty-table>
        </template>
        <template v-slot:cell(callingstationid)="item">
          <template v-if="item && item.value !== 'Total'">
            <router-link :to="{ name: 'node', params: { mac: item.value } }"><mac>{{ item.value }}</mac></router-link>
          </template>
          <template v-else>
            {{ item.value }}
          </template>
        </template>
        <template v-slot:cell(mac)="item">
          <template v-if="item && item.value !== 'Total'">
            <router-link :to="{ name: 'node', params: { mac: item.value } }"><mac>{{ item.value }}</mac></router-link>
          </template>
          <template v-else>
            {{ item.value }}
          </template>
        </template>
        <template v-slot:cell(owner)="item">
          <template v-if="item && item.value !== 'Total'">
            <router-link :to="{ name: 'user', params: { pid: item.value } }">{{ item.value }}</router-link>
          </template>
          <template v-else>
            {{ item.value }}
          </template>
        </template>
        <template v-slot:cell(pid)="item">
          <template v-if="item && item.value !== 'Total'">
            <router-link :to="{ name: 'user', params: { pid: item.value } }">{{ item.value }}</router-link>
          </template>
          <template v-else>
            {{ item.value }}
          </template>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import apiCall from '@/utils/api'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfReportColumns as reportColumns,
  pfReportCategories as reportCategories
} from '@/globals/pfReports'
import pfReportChart from '@/components/pfReportChart'

export default {
  name: 'standard-report-chart',
  components: {
    pfEmptyTable,
    pfReportChart
  },
  props: {
    path: String, // from router
    start_datetime: String, // from router
    end_datetime: String // from router
  },
  data () {
    return {
      items: [],
      tableValues: [],
      requestPage: 1,
      pageSizeLimit: 100,
      isLoading: false,
      sortBy: undefined,
      sortDesc: false,
      apiEndpoint: '',
      tabIndex: 0,
      datetimeStart: '',
      datetimeEnd: ''
    }
  },
  computed: {
    /**
     *  Fields on which a search can be defined.
     *  The names must match the database schema.
     *  The keys must conform to the format of the b-form-select's options property.
     */
    fields () {
      return this.report.fields
    },
    /**
     * The columns that can be displayed in the results table.
     */
    columns () {
      return this.report.columns
    },
    visibleColumns () {
      return this.report.columns
    },
    /**
     * The tabs displayed above the results table.
     */
    tabs () {
      return this.report.tabs
    },
    range () {
      const { tabs: { [Math.max(0, this.tabIndex)] : { range = false } = {} } = {} } = this
      return range
    },
    /**
     * build report using routers' path,
     * flatten reportCategories into single array,
     * search array and return single report matching path.
     */
    report () {
      return reportCategories().map(category => category.reports.map(report => Object.assign({ category: category.name }, report))).reduce((l, n) => l.concat(n), []).filter(report => report.tabs.map(tab => tab.path).includes(this.path))[0]
    },
    totalRows () {
      return this.items.length
    }
  },
  methods: {
    /**
     * b-table sorts columns on pre-formatted values,
     * if exists, use a custom column sort,
     * otherwise use the default sort.
     */
    sortCompare (a, b, key) {
      if (reportColumns()[key].sort) {
        // custom sort
        return reportColumns()[key].sort(a[key], b[key])
      } else {
        // default sort
        return null
      }
    },
    apiCall () {
      if (!this.apiEndpoint) return
      this.items = []
      this.isLoading = true
      apiCall.get(this.apiEndpoint, {}).then(response => {
        const len = response.data.items.length - 1
        this.items = response.data.items.map((item, index) => {
          console.debug(item)
          return (this.report.chart && index === len)
            ? { ...item, ...{ _rowVariant: 'primary' } } // highlight totals
            : item
        })
        this.requestPage = 1
      }).catch(err => {
        return err
      }).finally(() => {
        this.isLoading = false
      })
    },
    getReportCategoryByPath (reportPath) {
      return reportCategories().find(category => {
        const { reports = [] } = category
        return reports.find(report => {
          const { tabs = [] } = report
          return tabs.find(tab => {
            const { path } = tab
            return path === reportPath
          })
        })
      })
    },
    getReportByPath (path) {
      return reportCategories().map(category => category.reports.map(report => Object.assign({ category: category.name }, report))).reduce((l, n) => l.concat(n), []).filter(report => report.tabs.map(tab => tab.path).includes(path))[0]
    },
    onChangeDatetimeStart (datetime) {
      this.datetimeStart = datetime
      const rpath = this.getApiEndpointRangePath(this.range)
      if (rpath) {
        this.apiEndpoint = `reports/${this.path}${rpath}`
      }
    },
    onChangeDatetimeEnd (datetime) {
      this.datetimeEnd = datetime
      const rpath = this.getApiEndpointRangePath(this.range)
      if (rpath) {
        this.apiEndpoint = `reports/${this.path}${rpath}`
      }
    },
    getApiEndpointRangePath (range) {
      const { datetimeStart, datetimeEnd } = this
      if (range && datetimeStart && datetimeEnd) {
        return `/${datetimeStart}/${datetimeEnd}`
      }
      return false
    },
    onSortingChanged () {
      // noop
    }
  },
  beforeRouteUpdate (to, from, next) {
    // trigger on every page-leave and only within same route '/reports'
    if (
      this.getReportCategoryByPath(from.params.path).name !== this.getReportCategoryByPath(to.params.path).name
      ||
      this.getReportByPath(to.params.path).name !== this.getReportByPath(from.params.path).name
    ) {
      this.tabIndex = 0
    }
    const report = reportCategories().map(category => category.reports).reduce((l, n) => l.concat(n), []).filter(report => report.tabs.map(tab => tab.path).includes(to.params.path))[0]
    const { tabs: { [this.tabIndex]: { range = false } = {} } = {} } = report
    if (range) {
      const rpath = this.getApiEndpointRangePath(range)
      if (rpath) {
        this.apiEndpoint = `reports/${to.params.path}${rpath}`
      }
    } else {
      this.apiEndpoint = `reports/${to.params.path}`
    }
    next()
  },
  beforeRouteEnter (to, from, next) {
    // triggered only once on page-load to this route '/reports'
    next(vm => {
      vm.tabIndex = Math.max(0, vm.report.tabs.findIndex(tab => tab.path === to.params.path))
      const range = vm.report.tabs[vm.tabIndex].range
      if (range) {
        const rpath = vm.getApiEndpointRangePath(range)
        if (rpath) {
          vm.apiEndpoint = `reports/${to.params.path}${rpath}`
        }
      } else {
        vm.apiEndpoint = `reports/${to.params.path}`
      }
    })
  },
  watch: {
    apiEndpoint (a, b) {
      if (a && a !== b) {
        this.apiCall()
      }
    },
    tabIndex (a, b) {
      a = Math.max(0, a)
      if (a !== b) {
        this.items = []
        /**
         * mandatory `replace`,
         * `push` confuses beforeRouteEnter, beforeRouteUpdate w/ history.go(-1)
         */
        const newPath = `/reports/standard/chart/${this.report.tabs[a].path}`
        if (newPath !== this.$route.path) {
          this.$router.replace(newPath)
        }
      }
    }
  },
  created () {
    if (this.$can('read', 'nodes'))
      this.$store.dispatch('config/getRoles')
    // if range defined in route, prepopulate datetime fields
    this.datetimeStart = (this.start_datetime) ? this.start_datetime : ''
    this.datetimeEnd = (this.end_datetime) ? this.end_datetime : ''
  }
}
</script>
