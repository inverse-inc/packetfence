<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ $t('Report') }} / {{ $t(report.category) }} / {{ $t(report.name) }}</h4>
    </b-card-header>
    <pf-report-chart v-if="report.chart" :report="report" :items="items"></pf-report-chart>
    <!--<pf-search :fields="fields" :store="$store" storeName="$_reports" :advanced-mode="advancedMode" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset" @import-search="onImport"></pf-search>-->
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
      <b-table :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc" :sort-compare="sortCompare" v-model="tableValues"
        @sort-changed="onSortingChanged" responsive hover></b-table>
    </div>
  </b-card>
</template>

<script>
import {
  pfReportColumns as reportColumns,
  pfReportCategories as reportCategories
} from '@/globals/pfReports'
import pfReportChart from '@/components/pfReportChart'
import pfMixinSearchable from '@/components/pfMixinSearchable'

export default {
  name: 'ReportTable',
  components: {
    'pf-report-chart': pfReportChart
  },
  mixins: [
    pfMixinSearchable
  ],
  props: {
    pfMixinSearchableOptions: {
      type: Object,
      default: {
        searchApiEndpoint: undefined, // overwritten by router
        defaultSortKeys: ['mac'],
        defaultSearchCondition: { op: 'and', values: [{ op: 'or', values: [{ field: 'mac', op: 'equals', value: null }] }] },
        defaultRoute: { name: 'table' }
      }
    },
    path: String, // from router
    start_datetime: String, // from router
    end_datetime: String, // from router
    tableValues: {
      type: Array,
      default: []
    }
  },
  data () {
    return {
      requestPage: 1,
      currentPage: 1,
      pageSizeLimit: 10
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
    report () {
      /**
       * build report using routers' path,
       * flatten reportCategories into single array,
       * search array and return single report matching path
        */
      return reportCategories.map(category => category.reports.map(report => Object.assign({ category: category.name }, report))).reduce((l, n) => l.concat(n), []).filter(report => report.path === this.path)[0]
    }
  },
  methods: {
    sortCompare (a, b, key) {
      if (reportColumns[key].sort) {
        // custom sort
        return reportColumns[key].sort(a[key], b[key])
      } else {
        // default sort
        return null
      }
    }
  },
  beforeRouteUpdate (to, from, next) {
    // trigger on every page leave only within same route '/reports'
    let range = ''
    const report = reportCategories.map(category => category.reports).reduce((l, n) => l.concat(n), []).filter(report => report.path === to.params.path)[0]
    if (report.range.required || report.range.optional) {
      range += (to.params.start_datetime !== undefined) ? '/' + to.params.start_datetime : '/0000-00-00 00:00:00'
      range += (to.params.end_datetime !== undefined) ? '/' + to.params.end_datetime : '/9999-12-12 23:59:59'
    }
    this.pfMixinSearchableOptions.searchApiEndpoint = `reports/${to.params.path}${range}`
    next()
  },
  beforeRouteEnter (to, from, next) {
    // triggered only once on page load to this route '/reports'
    next(vm => {
      let range = ''
      if (vm.report.range.required || vm.report.range.optional) {
        range += (to.params.start_datetime !== undefined) ? '/' + to.params.start_datetime : '/0000-00-00 00:00:00'
        range += (to.params.end_datetime !== undefined) ? '/' + to.params.end_datetime : '/9999-12-12 23:59:59'
      }
      vm.pfMixinSearchableOptions.searchApiEndpoint = `reports/${to.params.path}${range}`
    })
  },
  created () {
    this.$store.dispatch('config/getRoles')
  }
}
</script>
