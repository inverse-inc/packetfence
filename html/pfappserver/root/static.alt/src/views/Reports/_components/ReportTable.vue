<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ $t('Report') }} / {{ $t(report.category) }} / {{ $t(report.name) }}</h4>
    </b-card-header>

    <b-tabs ref="tabs" v-model="tabIndex" card>
      <b-tab v-for="tab in tabs" :key="report.category + report.name + tab.name" :title="tab.name">
        <template slot="title">
          {{ $t(tab.name) }}
        </template>
        <!-- TABS ARE ONLY VISUAL, NOTHING NEEDED HERE... -->
      </b-tab>
    </b-tabs>

    <pf-report-chart v-if="report.chart" :report="report" :items="items"></pf-report-chart>

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
                <b-form-select class="mb-3 mr-3" size="sm" v-model="pageSizeLimit" :options="[10,25,50,100]" :disabled="isLoading"
                  @input="onPageSizeChange" />
              </b-form>
              <b-pagination align="right" v-model="requestPage" :per-page="pageSizeLimit" :total-rows="totalRows" :disabled="isLoading"
                @input="onPageChange" />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table stacked="sm" :items="items" :fields="visibleColumns" :per-page="pageSizeLimit" :current-page="requestPage" :sort-by="sortBy" :sort-desc="sortDesc" :sort-compare="sortCompare"
        @sort-changed="onSortingChanged" responsive="true" hover v-model="tableValues"></b-table>
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
      tabIndex: 0
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
    }
  },
  beforeRouteUpdate (to, from, next) {
    // trigger on every page-leave and only within same route '/reports'
    let range = ''
    const report = reportCategories.map(category => category.reports).reduce((l, n) => l.concat(n), []).filter(report => report.tabs.map(tab => tab.path).includes(to.params.path))[0]
    if (report.range.required || report.range.optional) {
      range += (to.params.start_datetime !== undefined) ? '/' + to.params.start_datetime : '/0000-00-00 00:00:00'
      range += (to.params.end_datetime !== undefined) ? '/' + to.params.end_datetime : '/9999-12-12 23:59:59'
    }
    if (this.getReportByPath(to.params.path).name !== this.getReportByPath(from.params.path).name) {
      this.tabIndex = 0
    }
    this.apiEndpoint = `reports/${to.params.path}${range}`
    next()
  },
  beforeRouteEnter (to, from, next) {
    // triggered only once on page-load to this route '/reports'
    next(vm => {
      let range = ''
      if (vm.report.range.required || vm.report.range.optional) {
        range += (to.params.start_datetime !== undefined) ? '/' + to.params.start_datetime : '/0000-00-00 00:00:00'
        range += (to.params.end_datetime !== undefined) ? '/' + to.params.end_datetime : '/9999-12-12 23:59:59'
      }
      vm.tabIndex = vm.report.tabs.findIndex(tab => tab.path === to.params.path)
      vm.apiEndpoint = `reports/${to.params.path}${range}`
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
        this.$router.push(`/reports/table/${this.report.tabs[a].path}`)
      }
    }
  },
  created () {
    this.$store.dispatch('config/getRoles')
  }
}
</script>
