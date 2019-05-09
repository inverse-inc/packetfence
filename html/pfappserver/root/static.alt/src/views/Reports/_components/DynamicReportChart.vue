<template>
  <b-card no-body>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0">{{ $t(report.description) }}</h4>
      <p v-if="report.long_description" v-t="report.long_description" class="mt-3 mb-0"></p>
    </b-card-header>
    <pf-search v-if="parsedSearches.length > 0"
      :quick-placeholder="quickSearchPlaceholder"
      :quick-with-fields="false"
      :fields="fields"
      :advanced-mode="advancedMode"
      :condition="condition"
      :storeName="storeName"
      :save-search-namespace="`dymamicReports::${id}`"
      @submit-search="onSearch"
      @reset-search="onReset"
      @import-search="onImport"
      class="pb-0"
    ></pf-search>
    <b-container id="DynamicReportChartDates" fluid>
      <b-row class="my-3" align-h="between" align-v="center">
        <b-col cols="auto" class="text-left">
          <b-form inline>
            <b-btn variant="link" id="periods">
              <icon name="stopwatch"></icon>
            </b-btn>
            <b-popover class="popover-full" target="periods" triggers="click focus blur" placement="bottomright" container="DynamicReportChartDates" :show.sync="showPeriod">
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
      </b-row>
    </b-container>
    <div class="card-body">
      <b-row align-h="between" align-v="center">
        <b-col cols="auto" class="mr-auto">
          <b-dropdown size="sm" variant="link" no-caret>
            <template slot="button-content">
              <icon name="columns" v-b-tooltip.hover.right :title="$t('Visible Columns')"></icon>
            </template>
            <template v-for="column in columns">
              <b-dropdown-item :key="column.key" v-if="column.locked" disabled>
                <icon class="position-absolute mt-1" name="thumbtack"></icon>
                <span class="ml-4">{{column.label}}</span>
              </b-dropdown-item>
              <a :key="column.key" v-else href="javascript:void(0)" :disabled="column.locked" class="dropdown-item" @click.stop="toggleColumn(column)">
                <icon class="position-absolute mt-1" name="check" v-show="column.visible"></icon>
                <span class="ml-4">{{column.label}}</span>
              </a>
            </template>
          </b-dropdown>
        </b-col>
        <b-col cols="auto">
          <b-container fluid>
            <b-row align-v="center">
              <b-form inline class="mb-0">
                <b-form-select class="mb-3 mr-3" size="sm" v-model="pageSizeLimit" :options="[25,50,100,200,500,1000]" :disabled="isLoading"
                  @input="onPageSizeChange" />
              </b-form>
              <b-pagination class="mr-3" align="right" :per-page="pageSizeLimit" :total-rows="totalRows" v-model="currentPage" :disabled="isLoading"
                @change="onPageChange" />
              <pf-button-export-to-csv class="mb-3" :filename="`${report.description}.csv`" :disabled="isLoading"
                :columns="visibleColumns" :data="items"
              />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc"
        @sort-changed="onSortingChanged"
        show-empty responsive hover no-local-sorting no-provider-sorting striped>
        <template slot="empty">
          <pf-empty-table :isLoading="isLoading">{{ $t('No report data found') }}</pf-empty-table>
        </template>
        <template v-for="nodeField in nodeFields" :slot="nodeField" slot-scope="data">
          <router-link :key="nodeField" :to="{ path: `/node/${data.value}` }">{{ data.value }}</router-link>
        </template>
        <template v-for="personField in personFields" :slot="personField" slot-scope="data">
          <router-link :key="personField" :to="{ path: `/user/${data.value}` }">{{ data.value }}</router-link>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import { format, subSeconds } from 'date-fns'
import pfButtonExportToCsv from '@/components/pfButtonExportToCsv'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormToggle from '@/components/pfFormToggle'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfSearch from '@/components/pfSearch'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export default {
  name: 'DynamicReportChart',
  mixins: [
    pfMixinSearchable
  ],
  components: {
    pfButtonExportToCsv,
    pfEmptyTable,
    pfFormDatetime,
    pfFormToggle,
    pfSearch
  },
  props: {
    storeName: { // from router
      type: String,
      default: null
    },
    id: { // from router
      type: String,
      default: null
    },
    searchableOptions: { // overloaded after `this.report` is set/reset
      type: Object,
      default: () => {}
    }
  },
  data () {
    return {
      report: {},
      advancedMode: false,
      fields: [],
      columns: [],
      datetimeStart: null,
      datetimeEnd: null,
      maxStartDatetime: '9999-12-12 23:59:59',
      minEndDatetime: '0000-00-00 00:00:00'
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    },
    parsedColumns () {
      let parsedColumns = []
      const regex = [
        /^([a-z0-9_]+)\.([a-z0-9_]+) as [\\]?["'`]?([a-z0-9 ]*)[\\]?["'`]?/i,
        /^([a-z0-9_]+)\.([a-z0-9_]+) [\\]?["'`]?([a-z0-9 ]*)[\\]?["'`]?/i
      ]
      const { report: { columns = null } = {} } = this
      if (columns) {
        if (columns === '*') {
          parsedColumns.push({ table: '*', column: '*', alias: '*' })
        } else {
          columns.split(',').forEach(col => {
            for (let i = 0; i < regex.length; i++) {
              if (regex[i].test(col.trim())) {
                // eslint-disable-next-line no-unused-vars
                const [ _, table, column, alias ] = col.trim().match(regex[i])
                parsedColumns.push({ table, column, alias })
                break
              }
            }
          })
        }
      }
      return parsedColumns
    },
    parsedSearches () {
      let parsedSearches = []
      const { report: { searches = null } = {} } = this
      if (searches) {
        searches.split(',').forEach(section => {
          const [ type, alias, key ] = section.split(':')
          const [ table, column ] = key.split('.')
          parsedSearches.push({ type, alias, table, column })
        })
      }
      return parsedSearches
    },
    nodeFields () {
      const { report: { node_fields: nodeFields = '' } = {} } = this
      return nodeFields.split(',')
    },
    personFields () {
      const { report: { person_fields: personFields = '' } = {} } = this
      return personFields.split(',')
    },
    quickSearchPlaceholder () {
      let names = []
      this.parsedSearches.forEach(search => {
        names.push(this.$i18n.t(search.alias)) // pre-translate
      })
      names.sort((a, b) => b.localeCompare(a)) // reversed sort
      const [ last, ...csv ] = names // group
      if (csv) {
        return this.$i18n.t('Search for {csv} or {last}', { csv: csv.reverse().join(', '), last: last })
      } else {
        return this.$i18n.t('Search for {only}', { only: last })
      }
    }
  },
  methods: {
    searchableQuickCondition (quickCondition) {
      const searchCriteria = this.parsedSearches.map(search => {
        return { field: `${search.table}.${search.column}`, op: 'contains', value: quickCondition || null }
      })
      return { op: 'and', values: [{ op: 'or', values: searchCriteria }] }
    },
    searchableAdvancedMode (condition) {
      if (condition) {
        return condition.values.length > 1 ||
          condition.values[0].values.filter(v => {
            return this.searchableOptions.defaultSearchCondition.values[0].values.findIndex(d => {
              return d.field === v.field && d.op === v.op
            }) >= 0
          }).length !== condition.values[0].values.length
      }
      return false
    },
    init () {
      this.$store.dispatch(`${this.storeName}/getReport`, this.id).then(report => {
        this.report = report
        this.buildPropsFromReport()
      })
    },
    buildPropsFromReport () {
      // build `columns` (before searchableOptions)
      let columns = this.parsedColumns.map(column => {
        return {
          key: column.alias,
          label: this.$i18n.t(column.alias),
          sortable: false, // TODO - enable backend sorting
          visible: true
        }
      })
      this.$set(this, 'columns', columns)

      // build `fields` (before searchableOptions)
      let fields = []
      if ('date_field' in this.report) { // first
        let column = this.parsedColumns.find(search => search.column === this.report.date_field)
        if (column) {
          fields.push({
            value: `${column.table}.${column.column}`,
            text: this.$i18n.t(column.alias),
            types: [conditionType.DATETIME]
          })
        }
      }
      fields.push(...this.parsedSearches.map(column => { // remainder
        return {
          value: `${column.table}.${column.column}`,
          text: this.$i18n.t(column.alias),
          types: [conditionType.SUBSTRING]
        }
      }).sort((a, b) => a.text.localeCompare(b.text)))
      this.$set(this, 'fields', fields)

      // build `searchableOptions`
      const searchCriteria = this.parsedSearches.map(search => {
        return { field: `${search.table}.${search.column}`, op: 'contains', value: null }
      })
      let searchableOptions = {
        searchApiEndpoint: `dynamic_report/${this.id}`,
        defaultSortKeys: [], // no local sorting
        defaultSortDesc: false, // no local sorting
        defaultSearchCondition: { op: 'and', values: [{ op: 'or', values: searchCriteria }] },
        defaultRoute: { name: 'dynamicReportChart', params: { id: this.id } },
        extraFields: { 'start_date': this.datetimeStart, 'end_date': this.datetimeEnd }
      }
      this.$set(this, 'searchableOptions', searchableOptions)
    },
    setRangeByPeriod (period) {
      this.datetimeEnd = format(new Date(), 'YYYY-MM-DD HH:mm:ss')
      this.datetimeStart = format(subSeconds(new Date(), period), 'YYYY-MM-DD HH:mm:ss')
    }
  },
  created () {
    this.init()
  },
  watch: {
    id (a, b) {
      if (a && a !== b) {
        this.init()
      }
    },
    items (a, b) {
      if (a.length > 0 && this.columns.length === 1) { // columns were not initially known
        const columns = Object.keys(a[0]).map(column => {
          return {
            key: column,
            label: column,
            sortable: false,
            visible: true
          }
        })
        if (JSON.stringify(columns) !== JSON.stringify(this.columns)) {
          this.$set(this, 'columns', columns)
        }
      }
    },
    datetimeStart (a, b) {
      if (a !== b) {
        this.minEndDatetime = a
        this.buildPropsFromReport()
      }
    },
    datetimeEnd (a, b) {
      if (a !== b) {
        this.maxStartDatetime = a
        this.buildPropsFromReport()
      }
    }

  }
}
</script>

<style>
/**
 * Don't limit the size of the popover
 */
#DynamicReportChartDates .popover {
  max-width: none;
}
</style>

<style lang="scss" scoped>
@import "../../../../node_modules/bootstrap/scss/functions";
@import "../../../styles/variables";

/**
 * Add btn-primary color(s) on hover
 */
.btn-group[rel=periodButtonGroup] button:hover {
  border-color: $input-btn-hover-bg-color;
  background-color: $input-btn-hover-bg-color;
  color: $input-btn-hover-text-color;
}

</style>
