<template>
  <div>
    <slot name="pageHeader"></slot>
    <pf-search ref="pfSearch"
      :quick-with-fields="false"
      :quick-placeholder="$t(config.searchPlaceholder)"
      :fields="fields"
      :store="$store"
      :advanced-mode="false"
      :condition="condition"
      @submit-search="onSearch"
      @reset-search="onReset"
    ></pf-search>
    <div class="card-body pt-0">
      <b-row>
        <b-col cols="auto" class="mr-auto mb-3">
          <slot name="buttonAdd"></slot>
        </b-col>
      </b-row>
      <b-row align-h="end" align-v="center">
        <b-col>
          <b-dropdown size="sm" variant="link" :boundary="$refs.container" no-caret>
            <template v-slot:button-content>
              <icon name="columns" v-b-tooltip.hover.top.d300.window :title="$t('Visible Columns')"></icon>
            </template>
            <template v-for="column in columns">
              <template v-if="column.label">
                <b-dropdown-item :key="column.key" v-if="column.locked" disabled>
                  <icon class="position-absolute mt-1" name="thumbtack"></icon>
                  <span class="ml-4">{{ $t(column.label) }}</span>
                </b-dropdown-item>
                <a :key="column.key" v-else href="javascript:void(0)" :disabled="column.locked" class="dropdown-item" @click.stop="toggleColumn(column)">
                  <icon class="position-absolute mt-1" name="check" v-show="column.visible"></icon>
                  <span class="ml-4">{{ $t(column.label) }}</span>
                </a>
              </template>
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
              <pf-button-export-to-csv class="mb-3" :filename="`${$route.path.slice(1).replace('/', '-')}.csv`" :disabled="isLoading"
                :columns="columns" :data="items"
              />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <slot name="tableHeader"></slot>

      <pf-table-sortable v-if="sortable"
        :items="items"
        :fields="visibleColumns"
        @row-clicked="onRowClick"
        hover
        striped
        @end="sort"
      >
        <template v-slot:empty>
          <slot name="emptySearch" v-bind="{ isLoading }">
            <pf-empty-table :isLoading="isLoading">{{ $t('No results found') }}</pf-empty-table>
          </slot>
        </template>
        <!-- Proxy all possible column slots ([field]) into pf-table-sortable slots -->
        <template v-for="column in config.columns" v-slot:[cell(column.key)]="item">
          <slot :name="cell(column.key)" v-bind="item">{{ item[column.key] }}</slot>
        </template>
      </pf-table-sortable>

      <b-table class="table-clickable" v-else
        :items="items"
        :fields="visibleColumns"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        :hover="items.length > 0"
        @sort-changed="onSortingChanged"
        @row-clicked="onRowClick"
        show-empty
        responsive
        fixed
        sort-icon-left
        striped
      >
        <template v-slot:empty>
          <slot name="emptySearch" v-bind="{ isLoading }">
              <pf-empty-table :isLoading="isLoading">{{ $t('No results found') }}</pf-empty-table>
          </slot>
        </template>
        <!-- Proxy all possible column slots ([field], HEAD_[field], FOOT_[field]) into b-table slots -->
        <template v-for="column in config.columns" v-slot:[cell(column.key)]="data">
          <slot :name="cell(column.key)" v-bind="data.item">{{ data.item[column.key] }}</slot>
        </template>
        <template v-for="column in config.columns" v-slot:[head(column.key)]="data">
          <slot :name="head(column.key)">{{ $t(data.label) }}</slot>
        </template>
        <template v-for="column in config.columns" v-slot:[foot(column.key)]="data">
          <slot :name="foot(column.key)">{{ $t(data.label) }}</slot>
        </template>
      </b-table>

    </div>
  </div>
</template>

<script>
import pfButtonExportToCsv from '@/components/pfButtonExportToCsv'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfSearch from '@/components/pfSearch'
import pfTableSortable from '@/components/pfTableSortable'

export default {
  name: 'pf-config-list',
  mixins: [
    pfMixinSearchable
  ],
  components: {
    pfButtonExportToCsv,
    pfEmptyTable,
    pfSearch,
    pfTableSortable
  },
  props: {
    config: {
      type: Object,
      default: () => ({
        columns: [],
        fields: [],
        rowClickRoute () { return {} },
        searchPlaceholder: 'Search',
        searchableOptions: {
          searchApiEndpoint: null,
          defaultSortKeys: [],
          defaultSearchCondition: {
            op: 'and',
            values: [{
              op: 'or',
              values: [
                { field: 'id', op: 'contains', value: null },
                { field: 'notes', op: 'contains', value: null }
              ]
            }]
          },
          defaultRoute: { name: null }
        },
        searchableQuickCondition: (quickCondition) => {
          return {
            op: 'and',
            values: [
              {
                op: 'or',
                values: [
                  { field: 'id', op: 'contains', value: quickCondition },
                  { field: 'notes', op: 'contains', value: quickCondition }
                ]
              }
            ]
          }
        }
      })
    },
    tableValues: {
      type: Array,
      default: () => { return [] }
    },
    sortable: {
      type: Boolean,
      default: false
    }
  },
  computed: {
    fields () {
      return this.config.fields
    },
    columns () {
      return this.config.columns
    },
    searchableOptions () {
      return this.config.searchableOptions
    },
    searchableQuickCondition () {
      return this.config.searchableQuickCondition
    }
  },
  methods: {
    head (name) {
      return `head(${name})`
    },
    cell (name) {
      return `cell(${name})`
    },
    foot (name) {
      return `foot(${name})`
    },
    onRowClick (item, index) {
      this.$router.push(this.config.rowClickRoute(item, index))
    },
    resetSearch () {
      this.$refs.pfSearch.onReset()
    },
    submitSearch () {
      this.$refs.pfSearch.onSubmit()
    },
    refreshList () {
      this.resetSearch()
    }
  }
}
</script>
