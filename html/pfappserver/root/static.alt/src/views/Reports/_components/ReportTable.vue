<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ $t('Report') }} / {{ $t(report.category) }} / {{ $t(report.name) }}</h4>
    </b-card-header>

    <b-tabs ref="tabs" v-model="tabIndex" card>
      <b-tab v-for="tab in tabs" :key="report.category + report.name + tab.name" :title="tab.name" no-body>
        <template slot="title">
          {{ $t(tab.name) }}
        </template>
        <!-- TABS ARE ONLY VISUAL, NOTHING HERE... -->
      </b-tab>
    </b-tabs>

    <pf-report-chart v-if="report.chart" :report="report" :range="range && (range.optional || range.mandatory)" :items="items" :datetime-start="datetimeStart" :datetime-end="datetimeEnd" @changeDatetimeStart="onChangeDatetimeStart" @changeDatetimeEnd="onChangeDatetimeEnd" class="mt-3"></pf-report-chart>

    <div class="card-body">
      <b-row align-h="between" align-v="center">
        <b-col cols="auto" class="mr-auto">
          <b-dropdown size="sm" variant="link" boundary="viewport" :disabled="isLoading" no-caret>
            <template slot="button-content">
              <icon name="columns" v-b-tooltip.hover.right.d1000 :title="$t('Visible Columns')"></icon>
            </template>
            <b-dropdown-item v-for="column in columns" :key="column.key" @click="toggleColumn(column)" :disabled="column.locked">
              <icon class="position-absolute mt-1" name="thumbtack" v-show="column.visible" v-if="column.locked"></icon>
              <icon class="position-absolute mt-1" name="check" v-show="column.visible" v-else></icon>
              <span class="ml-4">{{column.label}}</span>
            </b-dropdown-item>
          </b-dropdown>
        </b-col>
        <b-col cols="auto">
          <b-container fluid>
            <b-row align-v="center">
              <b-form inline class="mb-0">
                <b-form-select class="mb-3 mr-3" size="sm" v-model="pageSizeLimit" :options="[25,50,100,200,500,1000]" :disabled="isLoading"
                  @input="onPageSizeChange" />
              </b-form>
              <b-pagination align="right" v-model="requestPage" :per-page="pageSizeLimit" :total-rows="totalRows" :disabled="isLoading"
                @input="onPageChange" />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table :items="items" :fields="visibleColumns" :per-page="pageSizeLimit" :current-page="requestPage" :sort-by="sortBy" :sort-desc="sortDesc" :sort-compare="sortCompare"
        @sort-changed="onSortingChanged" show-empty responsive hover striped v-model="tableValues">
        <template slot="empty">
          <pf-empty-table :isLoading="isLoading">{{ $t('No data found') }}</pf-empty-table>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import apiCall from '@/utils/api'
import {
  pfReportColumns as reportColumns,
  pfReportCategories as reportCategories
} from '@/globals/pfReports'
import pfReportChart from '@/components/pfReportChart'

export default {
  name: 'ReportTable',
  components: {
    'pf-report-chart': pfReportChart
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
      return this.tabs[this.tabIndex].range
    },
    /**
     * build report using routers' path,
     * flatten reportCategories into single array,
     * search array and return single report matching path.
     */
    report () {
      return reportCategories.map(category => category.reports.map(report => Object.assign({ category: category.name }, report))).reduce((l, n) => l.concat(n), []).filter(report => report.tabs.map(tab => tab.path).includes(this.path))[0]
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
      if (reportColumns[key].sort) {
        // custom sort
        return reportColumns[key].sort(a[key], b[key])
      } else {
        // default sort
        return null
      }
    },
    apiCall () {
      if (!this.apiEndpoint) return
      this.isLoading = true
      let _this = this
      apiCall.get(this.apiEndpoint, {}).then(response => {
        _this.items = response.data.items
        _this.requestPage = 1
        _this.isLoading = false
      }).catch(err => {
        _this.isLoading = false
        return err
      })
    },
    getReportByName (name) {
      return reportCategories.map(category => category.reports.map(report => Object.assign({ category: category.name }, report))).reduce((l, n) => l.concat(n), []).filter(report => report.name === name)[0]
    },
    getReportByPath (path) {
      return reportCategories.map(category => category.reports.map(report => Object.assign({ category: category.name }, report))).reduce((l, n) => l.concat(n), []).filter(report => report.tabs.map(tab => tab.path).includes(path))[0]
    },
    onChangeDatetimeStart (datetime) {
      this.datetimeStart = datetime
      const rpath = this.getApiEndpointRangePath(this.range)
      this.apiEndpoint = `reports/${this.path}${rpath}`
    },
    onChangeDatetimeEnd (datetime) {
      this.datetimeEnd = datetime
      const rpath = this.getApiEndpointRangePath(this.range)
      this.apiEndpoint = `reports/${this.path}${rpath}`
    },
    getApiEndpointRangePath (range) {
      let rpath = ''
      if (range && (range.required || range.optional)) {
        rpath += (this.datetimeStart) ? '/' + this.datetimeStart : '/0000-00-00 00:00:00'
        rpath += (this.datetimeEnd) ? '/' + this.datetimeEnd : '/9999-12-12 23:59:59'
      }
      return rpath
    }
  },
  beforeRouteUpdate (to, from, next) {
    // trigger on every page-leave and only within same route '/reports'
    if (this.getReportByPath(to.params.path).name !== this.getReportByPath(from.params.path).name) {
      this.tabIndex = 0
    }
    const report = reportCategories.map(category => category.reports).reduce((l, n) => l.concat(n), []).filter(report => report.tabs.map(tab => tab.path).includes(to.params.path))[0]
    const range = report.tabs[this.tabIndex].range
    const rpath = this.getApiEndpointRangePath(range)
    this.apiEndpoint = `reports/${to.params.path}${rpath}`
    next()
  },
  beforeRouteEnter (to, from, next) {
    // triggered only once on page-load to this route '/reports'
    next(vm => {
      vm.tabIndex = vm.report.tabs.findIndex(tab => tab.path === to.params.path)
      const range = vm.report.tabs[vm.tabIndex].range
      const rpath = vm.getApiEndpointRangePath(range)
      vm.apiEndpoint = `reports/${to.params.path}${rpath}`
    })
  },
  watch: {
    apiEndpoint (a, b) {
      if (a && a !== b) {
        this.apiCall()
      }
    },
    tabIndex (a, b) {
      if (a !== b) {
        /**
         * mandatory `replace`,
         * `push` confuses beforeRouteEnter, beforeRouteUpdate w/ history.go(-1)
         */
        this.$router.replace(`/reports/table/${this.report.tabs[a].path}`)
      }
    }
  },
  created () {
    this.$store.dispatch('config/getRoles')
    // if range defined in route, prepopulate datetime fields
    this.datetimeStart = (this.start_datetime) ? this.start_datetime : ''
    this.datetimeEnd = (this.end_datetime) ? this.end_datetime : ''
  }
}
</script>
