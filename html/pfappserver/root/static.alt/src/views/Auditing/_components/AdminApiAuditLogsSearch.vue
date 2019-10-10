<template>
  <b-card no-body>
    <pf-progress :active="isLoading"></pf-progress>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Search Admin API Audit Audit Logs'"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" :quick-placeholder="$t('Search by MAC or IP')" save-search-namespace="admin_api_audit_logs"
      :fields="fields" :storeName="storeName" :advanced-mode="advancedMode" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset" @import-search="onImport"></pf-search>
    <div class="card-body">
      <b-row align-h="between" align-v="center">
        <b-col cols="auto" class="mr-auto">
          <b-dropdown size="sm" variant="link" :disabled="isLoading || selectValues.length === 0" no-caret no-flip>
            <template slot="button-content">
              <icon name="cog" v-b-tooltip.hover.top.d300 :title="$t('Bulk Actions')"></icon>
            </template>
          </b-dropdown>
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
        show-empty responsive hover no-local-sorting striped
      >
        <template slot="HEAD_actions">
          <b-form-checkbox id="checkallnone" v-model="selectAll" @change="onSelectAllChange"></b-form-checkbox>
          <b-tooltip target="checkallnone" placement="right" v-if="selectValues.length === tableValues.length">{{ $t('Select None [Alt + N]') }}</b-tooltip>
          <b-tooltip target="checkallnone" placement="right" v-else>{{ $t('Select All [Alt + A]') }}</b-tooltip>
        </template>
        <template slot="actions" slot-scope="data">
          <div class="text-nowrap">
            <b-form-checkbox :id="data.value" :value="data.item" v-model="selectValues" @click.native.stop="onToggleSelected($event, data.index)"></b-form-checkbox>
            <icon name="exclamation-triangle" class="ml-1" v-if="tableValues[data.index] && tableValues[data.index]._rowMessage" v-b-tooltip.hover.right :title="tableValues[data.index]._rowMessage"></icon>
          </div>
        </template>
        <div slot="answer" slot-scope="{ value }" v-html="value"></div>
        <template slot="empty">
          <pf-empty-table :isLoading="isLoading" :text="$t('Admin API Audit Audit Logs not found or setting is disabled in configuration.(You can enable this setting in Configuration->System Configuration->Admin API Audit Configuration)')">{{ $t('No logs found') }}</pf-empty-table>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import api from '../_api'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import pfButtonExportToCsv from '@/components/pfButtonExportToCsv'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfMixinSelectable from '@/components/pfMixinSelectable'
import pfProgress from '@/components/pfProgress'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfSearch from '@/components/pfSearch'
import pfFormToggle from '@/components/pfFormToggle'

export default {
  name: 'admin-api-audit-logs-search',
  mixins: [
    pfMixinSelectable,
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
              { field: 'action', op: 'contains', value: null },
              { field: 'user_name', op: 'contains', value: null }
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
          text: this.$i18n.t('object_id'),
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
          key: 'actions',
          label: this.$i18n.t('Actions'),
          locked: true,
          formatter: (value, key, item) => {
            return item.id
          }
        },
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
              { field: 'object_id', op: 'contains', value: quickCondition },
              { field: 'user_name', op: 'contains', value: quickCondition }
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
    onRowClick (item, index) {
      this.$router.push({ name: 'admin_api_audit_log', params: { id: item.id } })
    }
  }
}
</script>
