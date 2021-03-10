<template>
  <b-card ref="container" no-body>
    <pf-progress :active="isLoading"></pf-progress>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Search Admin API Audit Logs'"></h4>
    </b-card-header>
    <pf-search class="flex-shrink-0"
      :quick-with-fields="false"
      :quick-placeholder="$t('Search by user name, action or object id')"
      save-search-namespace="admin_api_audit_logs"
      :fields="fields"
      :advanced-mode="advancedMode"
      :condition="condition"
      :storeName="storeName"
      @submit-search="onSearch"
      @reset-search="onReset"
      @import-search="onImport"></pf-search>
    <div class="card-body flex-shrink-0 pt-0">
      <b-row align-h="between" align-v="center">
        <b-col cols="auto" class="mr-auto">
          <b-dropdown size="sm" variant="link" :boundary="$refs.container" no-caret>
            <template v-slot:button-content>
              <icon name="columns" v-b-tooltip.hover.right :title="$t('Visible Columns')"></icon>
            </template>
            <template v-for="column in columns">
              <b-dropdown-item :key="column.key" v-if="column.locked" disabled>
                <icon class="position-absolute mt-1" name="thumbtack"></icon>
                <span class="ml-4">{{ $t(column.label) }}</span>
              </b-dropdown-item>
              <a :key="column.key" v-else href="javascript:void(0)" :disabled="column.locked" class="dropdown-item" @click.stop="toggleColumn(column)">
                <icon class="position-absolute mt-1" name="check" v-show="column.visible"></icon>
                <span class="ml-4">{{ $t(column.label) }}</span>
              </a>
            </template>
          </b-dropdown>
        </b-col>
        <b-col cols="auto">
          <b-container fluid>
            <b-row align-v="center">
              <b-form inline class="mb-0">
                <b-form-select class="mr-3" size="sm" v-model="pageSizeLimit" :options="[25,50,100,200,500,1000]" :disabled="isLoading"
                  @input="onPageSizeChange" />
              </b-form>
              <b-pagination class="mr-3 my-0" align="right" :per-page="pageSizeLimit" :total-rows="totalRows" :last-number="true" v-model="currentPage" :disabled="isLoading"
                @change="onPageChange" />
              <base-button-export-csv filename="admin_api_audit_logs.csv" :disabled="isLoading"
                :columns="columns" :data="items"
              />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
    </div>
    <div class="card-body pt-0" v-scroll-100>
      <b-table
        class="table-clickable"
        :items="items"
        :fields="visibleColumns"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        @sort-changed="onSortingChanged"
        @row-clicked="onRowClick"
        show-empty hover no-local-sorting sort-icon-left striped
      >
        <template v-slot:empty>
          <pf-empty-table :isLoading="isLoading" :text="$t('Please refine your search.')">{{ $t('No logs found') }}</pf-empty-table>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import {
  BaseButtonExportCsv
} from '@/components/new/'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfProgress from '@/components/pfProgress'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfSearch from '@/components/pfSearch'
import pfFormToggle from '@/components/pfFormToggle'
import scroll100 from '@/directives/scroll-100'

export default {
  name: 'admin-api-audit-logs-search',
  mixins: [
    pfMixinSearchable
  ],
  components: {
    BaseButtonExportCsv,
    pfProgress,
    pfEmptyTable,
    pfSearch,
    pfFormToggle
  },
  directives: {
    scroll100
  },
  props: {
    searchableOptions: {
      type: Object,
      default: () => ({
        searchApiEndpoint: 'admin_api_audit_logs',
        defaultSortKeys: ['created_at'],
        defaultSortDesc: true,
        defaultSearchCondition: {
          op: 'and',
          values: [{
            op: 'or',
            values: [
              { field: 'user_name', op: 'contains', value: null },
              { field: 'action', op: 'contains', value: null },
              { field: 'object_id', op: 'contains', value: null }
            ]
          }]
        },
        defaultRoute: { name: 'admin_api_audit_logs' }
      })
    },
    storeName: {
      type: String,
      default: null
    }
  },
  data () {
    return {
      tableValues: Array,
      // Fields must match the database schema
      fields: [ // keys match with b-form-select
        {
          value: 'created_at',
          text: 'Created', // i18n defer
          types: [conditionType.DATETIME]
        },
        {
          value: 'user_name',
          text: 'User Name', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'action',
          text: 'Action', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'object_id',
          text: 'Object ID', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'url',
          text: 'URL', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'method',
          text: 'Scope', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'status',
          text: 'Status', // i18n defer
          types: [conditionType.SUBSTRING]
        }
      ],
      columns: [
        {
          key: 'id',
          label: 'Log ID', // i18n defer
          required: true,
          sortable: true
        },
        {
          key: 'created_at',
          label: 'Created At', // i18n defer
          sortable: true,
          visible: true,
          class: 'text-nowrap',
          formatter: formatter.datetimeIgnoreZero
        },
        {
          key: 'user_name',
          label: 'User Name', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'action',
          label: 'Action', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'object_id',
          label: 'Object ID', // i18n defer
          sortable: false,
          visible: true
        },
        {
          key: 'url',
          label: 'URL', // i18n defer
          sortable: false
        },
        {
          key: 'method',
          label: 'Method', // i18n defer
          sortable: false
        },
        {
          key: 'status',
          label: 'Status', // i18n defer
          sortable: false,
          visible: true
        }
      ]
    }
  },
  methods: {
    searchableQuickCondition (quickCondition) {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'user_name', op: 'contains', value: quickCondition },
              { field: 'action', op: 'contains', value: quickCondition },
              { field: 'object_id', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    },
    searchableAdvancedMode (condition) {
      return condition.values.length > 1 ||
        condition.values[0].values.filter(v => {
          return this.searchableOptions.defaultSearchCondition.values[0].values.findIndex(d => {
            return d.field === v.field && d.op === v.op
          }) >= 0
        }).length !== condition.values[0].values.length
    },
    onRowClick (item) {
      this.$router.push({ name: 'admin_api_audit_log', params: { id: item.id } })
    }
  }
}
</script>
