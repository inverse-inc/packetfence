<template>
  <b-card no-body>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0">{{ $t(report.description) }}</h4>
      <p v-if="report.long_description" v-t="report.long_description" class="mt-3 mb-0"></p>
    </b-card-header>
    <pf-search
      :quick-placeholder="quickSearchPlaceholder"
      :quick-with-fields="false"
      :fields="fields"
      :advanced-mode="advancedMode"
      :condition="condition"
      @submit-search="onSearch"
      @reset-search="onReset"
      @import-search="onImport"
    ></pf-search>
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
              <a :key="column.key" v-else href="#" :disabled="column.locked" class="dropdown-item" @click.stop="toggleColumn(column)">
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
              <b-pagination align="right" :per-page="pageSizeLimit" :total-rows="totalRows" v-model="requestPage" :disabled="isLoading"
                @input="onPageChange" />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc"
        show-empty responsive no-local-sorting striped>
        <template slot="empty">
          <pf-empty-table :isLoading="isLoading">{{ $t('No report data found') }}</pf-empty-table>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import pfEmptyTable from '@/components/pfEmptyTable'
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
    pfEmptyTable,
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
      columns: []
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
          key: `${column.table}.${column.column}`,
          label: this.$i18n.t(column.alias),
          sortable: true,
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
        defaultSortKeys: [`${this.parsedSearches[0].table}.${this.parsedSearches[0].column}`],
        defaultSortDesc: false,
        defaultSearchCondition: { op: 'and', values: [{ op: 'or', values: searchCriteria }] },
        defaultRoute: { name: 'dynamicReportChart', params: { id: this.id } }
      }
      if ('date_field' in this.report) {
        let search = this.parsedColumns.find(search => search.column === this.report.date_field)
        if (search) {
          searchableOptions.defaultSortKeys = [`${search.table}.${search.column}`]
          searchableOptions.defaultSortDesc = true
        }
      }
      this.$set(this, 'searchableOptions', searchableOptions)
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
    }
  }
}
</script>
