<template>
  <b-card ref="container" no-body>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Search DNS Audit Logs'"></h4>
    </b-card-header>
    <pf-search class="flex-shrink-0"
      :quick-with-fields="false"
      :quick-placeholder="$t('Search by MAC or IP')"
      save-search-namespace="dnslogs"
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
          <b-dropdown size="sm" variant="link" :disabled="isLoading || selectValues.length === 0" no-caret no-flip>
            <template v-slot:button-content>
              <icon name="cog" v-b-tooltip.hover.top.d300 :title="$t('Bulk Actions')"></icon>
            </template>
            <b-dropdown-item @click="addToPassthroughs()">
              <icon class="position-absolute mt-1" name="door-open"></icon>
              <span class="ml-4">{{ $t('Add to Passthroughs') }}</span>
            </b-dropdown-item>
          </b-dropdown>
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
              <base-button-export-csv filename="dnslogs.csv" :disabled="isLoading"
                :columns="columns" :data="items"
              />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
    </div>
    <div class="card-body pt-0" v-scroll-100>
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
        show-empty hover no-local-sorting sort-icon-left striped
      >
        <template v-slot:head(actions)>
          <b-form-checkbox id="checkallnone" v-model="selectAll" @change="onSelectAllChange"></b-form-checkbox>
          <b-tooltip target="checkallnone" placement="right" v-if="selectValues.length === tableValues.length">{{ $t('Select None [Alt + N]') }}</b-tooltip>
          <b-tooltip target="checkallnone" placement="right" v-else>{{ $t('Select All [Alt + A]') }}</b-tooltip>
        </template>
        <template v-slot:cell(actions)="data">
          <div class="text-nowrap">
            <b-form-checkbox :id="data.value" :value="data.item" v-model="selectValues" @click.stop="onToggleSelected($event, data.index)"></b-form-checkbox>
            <icon name="exclamation-triangle" class="ml-1" v-if="tableValues[data.index] && tableValues[data.index]._rowMessage" v-b-tooltip.hover.right :title="tableValues[data.index]._rowMessage"></icon>
          </div>
        </template>
        <template v-slot:cell(mac)="{ value }">
          <router-link :to="{ path: `/node/${value}` }"><mac v-text="value"></mac></router-link>
        </template>
        <template v-slot:cell(answer)="{ value }">
          <div v-html="value"></div>
        </template>
        <template v-slot:empty>
          <pf-empty-table :is-loading="isLoading" :text="$t('DNS Audit Logs not found or setting is disabled in configuration. You can enable this setting in Configuration → System Configuration → DNS Configuration.')">{{ $t('No logs found') }}</pf-empty-table>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import {
  BaseButtonExportCsv
} from '@/components/new/'
import api from '../_api'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfMixinSelectable from '@/components/pfMixinSelectable'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfSearch from '@/components/pfSearch'
import pfFormToggle from '@/components/pfFormToggle'
import scroll100 from '@/directives/scroll-100'

export default {
  name: 'dns-logs-search',
  mixins: [
    pfMixinSelectable,
    pfMixinSearchable
  ],
  components: {
    BaseButtonExportCsv,
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
        searchApiEndpoint: 'dns_audit_logs',
        defaultSortKeys: ['created_at'],
        defaultSortDesc: true,
        defaultSearchCondition: {
          op: 'and',
          values: [{
            op: 'or',
            values: [
              { field: 'mac', op: 'contains', value: null },
              { field: 'ip', op: 'contains', value: null }
            ]
          }]
        },
        defaultRoute: { name: 'dnslogs' }
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
          value: 'ip',
          text: 'IP Address', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'mac',
          text: 'MAC Address', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'qname',
          text: 'DNS Request', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'qtype',
          text: 'DNS Type', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'scope',
          text: 'Scope', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'answer',
          text: 'DNS Answer', // i18n defer
          types: [conditionType.SUBSTRING]
        }
      ],
      columns: [
        {
          key: 'actions',
          label: 'Actions', // i18n defer
          locked: true,
          formatter: (value, key, item) => {
            return item.id
          }
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
          key: 'id',
          label: 'ID', // i18n defer
          required: true,
          sortable: true
        },
        {
          key: 'ip',
          label: 'IP Address', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'mac',
          label: 'MAC Address', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'qname',
          label: 'Qname', // i18n defer
          sortable: false,
          visible: true
        },
        {
          key: 'qtype',
          label: 'Qtype', // i18n defer
          sortable: false
        },
        {
          key: 'scope',
          label: 'Scope', // i18n defer
          sortable: false
        },
        {
          key: 'answer',
          label: 'Answer', // i18n defer
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
              { field: 'mac', op: 'contains', value: quickCondition },
              { field: 'ip', op: 'contains', value: quickCondition }
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
      this.$router.push({ name: 'dnslog', params: { id: item.id } })
    },
    addToPassthroughs () {
      const domains = this.selectValues.map(item => item.qname)
      this.$store.dispatch('config/getBaseFencing').then(fencing => {
        let passthroughs = fencing.passthroughs.split(/,/).filter(passthrough => passthrough.length) // TODO - #4063, deprecate comma-separated lists
        domains.forEach(domain => {
          if (!passthroughs.includes(domain)) {
            passthroughs.push(domain)
          }
        })
        api.setPassthroughs(passthroughs)
      })
    }
  }
}
</script>
