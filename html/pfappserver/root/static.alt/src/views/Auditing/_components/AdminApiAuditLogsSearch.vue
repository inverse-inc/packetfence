<template>
  <b-card no-body>
    <pf-progress :active="isLoading"></pf-progress>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Search Admin API Audit Logs'"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" :quick-placeholder="$t('Search by user name, action or object id')" save-search-namespace="admin_api_audit_logs"
      :fields="fields" :storeName="storeName" :advanced-mode="advancedMode" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset" @import-search="onImport"></pf-search>
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
              <pf-button-export-to-csv class="mb-3" filename="admin_api_audit_logs.csv" :disabled="isLoading"
                :columns="columns" :data="items"
              />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table
        v-model="tableValues"
        class="table-clickable"
        :items="items"
        :fields="visibleColumns"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        @sort-changed="onSortingChanged"
        @row-clicked="onRowClick"
        @head-clicked="clearSelected"
        show-empty responsive hover no-local-sorting sort-icon-left striped
      >
        <template v-slot:empty>
          <pf-empty-table :isLoading="isLoading" :text="$t('Admin API Audit Audit Logs not found or setting is disabled in configuration. You can enable this setting in Configuration → System Configuration → Admin API Audit Configuration.')">{{ $t('No logs found') }}</pf-empty-table>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import pfButtonExportToCsv from '@/components/pfButtonExportToCsv'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfProgress from '@/components/pfProgress'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfSearch from '@/components/pfSearch'
import pfFormToggle from '@/components/pfFormToggle'

export default {
  name: 'admin-api-audit-logs-search',
  mixins: [
    pfMixinSearchable
  ],
  components: {
    pfButtonExportToCsv,
    pfProgress,
    pfEmptyTable,
    pfSearch,
    pfFormToggle
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
      sortBy: 'created_at',
      sortDesc: true,
      // Fields must match the database schema
      fields: [ // keys match with b-form-select
        {
          value: 'created_at',
          text: this.$i18n.t('Created'),
          types: [conditionType.DATETIME]
        },
        {
          value: 'user_name',
          text: this.$i18n.t('User Name'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'action',
          text: this.$i18n.t('Action'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'object_id',
          text: this.$i18n.t('Object ID'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'url',
          text: this.$i18n.t('Admin API Audit Type'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'method',
          text: this.$i18n.t('Scope'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'status',
          text: this.$i18n.t('Admin API Audit Answer'),
          types: [conditionType.SUBSTRING]
        }
      ],
      columns: [
        {
          key: 'created_at',
          label: this.$i18n.t('Created At'),
          sortable: true,
          visible: true,
          class: 'text-nowrap',
          formatter: formatter.datetimeIgnoreZero
        },
        {
          key: 'id',
          label: this.$i18n.t('ID'),
          required: true,
          sortable: true
        },
        {
          key: 'user_name',
          label: this.$i18n.t('User Name'),
          sortable: true,
          visible: true
        },
        {
          key: 'action',
          label: this.$i18n.t('Action'),
          sortable: true,
          visible: true
        },
        {
          key: 'object_id',
          label: this.$i18n.t('Object Id'),
          sortable: false,
          visible: true
        },
        {
          key: 'url',
          label: this.$i18n.t('URL'),
          sortable: false
        },
        {
          key: 'method',
          label: this.$i18n.t('Method'),
          sortable: false
        },
        {
          key: 'status',
          label: this.$i18n.t('Status'),
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
