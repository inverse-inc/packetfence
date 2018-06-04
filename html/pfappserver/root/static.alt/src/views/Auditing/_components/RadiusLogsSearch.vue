<template>
  <b-card no-body>
    <b-card-header>
      <div class="float-right"><toggle-button v-model="advancedMode">{{ $t('Advanced') }}</toggle-button></div>
      <h4 class="mb-0" v-t="'Search RADIUS Audit Logs'"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" quick-placeholder="Search by MAC or username"
      :fields="fields" :store="$store" :advanced-mode="advancedMode" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset"></pf-search>
    <div class="card-body">
      <b-row align-h="between" align-v="center">
        <b-col cols="auto" class="mr-auto">
          <b-dropdown size="sm" variant="link" :disabled="isLoading" no-caret>
            <template slot="button-content">
              <icon name="columns" v-b-tooltip.hover.right :title="$t('Visible Columns')"></icon>
            </template>
            <b-dropdown-item v-for="column in columns" :key="column.key" @click="toggleColumn(column)"
              v-if="!column.locked || column.visible" :disabled="column.locked">
              <icon class="position-absolute mt-1" name="thumbtack" v-if="column.locked"></icon>
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
              <b-pagination align="right" :per-page="pageSizeLimit" :total-rows="totalRows" v-model="requestPage" :disabled="isLoading"
                @input="onPageChange" />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table hover :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc"
        @sort-changed="onSortingChanged" @row-clicked="onRowClick" no-local-sorting></b-table>
    </div>
  </b-card>
</template>

<script>
import { pfSearchConditionType as attributeType } from '@/globals/pfSearch'
import pfSearch from '@/components/pfSearch'
import ToggleButton from '@/components/ToggleButton'

export default {
  name: 'RadiusLogsSearch',
  components: {
    'pf-search': pfSearch,
    'toggle-button': ToggleButton
  },
  data () {
    return {
      advancedMode: false,
      // Fields must match the database schema
      fields: [ // keys match with b-form-select
        {
          value: 'user_name',
          text: 'Username',
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'mac',
          text: 'MAC Address',
          types: [attributeType.SUBSTRING]
        }
      ],
      columns: [
        {
          key: 'id',
          label: this.$i18n.t('ID'),
          sortable: true,
          visible: false,
          locked: true
        },
        {
          key: 'auth_status',
          label: this.$i18n.t('Auth Status'),
          sortable: true,
          visible: true
        },
        {
          key: 'mac',
          label: this.$i18n.t('MAC Address'),
          sortable: true,
          visible: true
        },
        {
          key: 'node_status',
          label: this.$i18n.t('Node Status'),
          sortable: true,
          visible: true
        },
        {
          key: 'user_name',
          label: this.$i18n.t('Username'),
          sortable: true,
          visible: true
        },
        {
          key: 'ip',
          label: this.$i18n.t('IP Address'),
          sortable: true,
          visible: true
        },
        {
          key: 'created_at',
          label: this.$i18n.t('Created At'),
          sortable: true,
          visible: true
        }
      ],
      condition: null,
      requestPage: 1,
      currentPage: 1,
      pageSizeLimit: 10
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_radiuslogs/isLoadingResults']
    },
    sortBy () {
      return this.$store.state.$_radiuslogs.searchSortBy
    },
    sortDesc () {
      return this.$store.state.$_radiuslogs.searchSortDesc
    },
    visibleColumns () {
      return this.columns.filter(column => column.visible)
    },
    searchFields () {
      return this.visibleColumns.filter(column => column.visible).map(column => column.key)
    },
    items () {
      return this.$store.state.$_radiuslogs.results
    },
    totalRows () {
      return this.$store.state.$_radiuslogs.searchMaxPageNumber * this.pageSizeLimit
    }
  },
  methods: {
    onSearch (newCondition) {
      let _this = this
      let condition = newCondition
      if (!this.advancedMode) {
        // Build quick search query
        condition = {
          op: 'or',
          values: [
            { field: 'mac', op: 'contains', value: newCondition },
            { field: 'user_name', op: 'contains', value: newCondition }
          ]
        }
      }
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch('$_radiuslogs/setSearchQuery', condition)
      this.$store.dispatch('$_radiuslogs/search', this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
        _this.condition = condition
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
    },
    onReset () {
      this.$store.dispatch('$_radiuslogs/setSearchQuery', null) // reset search
      this.$store.dispatch('$_radiuslogs/search', this.requestPage)
      this.requestPage = 1 // reset to the first page
      // Select first field
      this.condition = { op: 'and', values: [{ field: this.fields[0].value, op: null, value: null }] }
    },
    onPageSizeChange () {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch('$_radiuslogs/setSearchPageSize', this.pageSizeLimit)
      this.$store.dispatch('$_radiuslogs/search', this.requestPage)
    },
    onPageChange () {
      let _this = this
      this.$store.dispatch('$_radiuslogs/search', this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
    },
    onSortingChanged (params) {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch('$_radiuslogs/setSearchSorting', params)
      this.$store.dispatch('$_radiuslogs/search', this.requestPage)
    },
    toggleColumn (column) {
      column.visible = !column.visible
      this.$store.dispatch('$_radiuslogs/setVisibleColumns', this.columns.filter(column => column.visible).map(column => column.key))
      this.$store.dispatch('$_radiuslogs/setSearchFields', this.searchFields)
      if (column.visible) {
        this.$store.dispatch('$_radiuslogs/search', this.requestPage)
      }
    },
    onRowClick (item, index) {
      // this.$router.push({ name: 'view', params: { id: item.id } })
    }
  },
  created () {
    this.pageSizeLimit = this.$store.state.$_radiuslogs.searchPageSize
    // Restore search parameters
    this.condition = this.$store.state.$_radiuslogs.searchQuery
    if (!this.condition) {
      // Select first field
      this.condition = { op: 'and', values: [{ field: this.fields[0].value, op: null, value: null }] }
    } else {
      // Restore selection of advanced mode; check if condition matches a quick search
      this.advancedMode = !(this.condition.op === 'or' &&
        this.condition.values.length === 2 &&
        this.condition.values[0].field === 'mac' &&
        this.condition.values[0].op === 'contains' &&
        this.condition.values[1].field === 'user_name' &&
        this.condition.values[1].op === 'contains')
    }
    // Restore visibleColumns, overwrite defaults
    if (this.$store.state.$_radiuslogs.visibleColumns) {
      let visibleColumns = this.$store.state.$_radiuslogs.visibleColumns
      this.columns.forEach(function (column, index, columns) {
        columns[index].visible = visibleColumns.includes(column.key)
      })
    }
    this.$store.dispatch('$_radiuslogs/setSearchFields', this.searchFields)
    this.$store.dispatch('$_radiuslogs/search', this.requestPage)
  }
}
</script>
