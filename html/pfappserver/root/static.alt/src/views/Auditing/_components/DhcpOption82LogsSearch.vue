<template>
  <b-card ref="container" no-body>
    <pf-progress :active="isLoading"></pf-progress>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Search DHCP Option 82 Logs'"></h4>
    </b-card-header>
    <pf-search class="flex-shrink-0"
      :quick-with-fields="false"
      :quick-placeholder="$t('Search by MAC')"
      save-search-namespace="dhcpoption82s"
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
              <pf-button-export-to-csv filename="dhcpoption82logs.csv" :disabled="isLoading"
                :columns="columns" :data="items"
              />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
    </div>
    <div class="card-body pt-0" v-scroll-100>
      <b-table class="table-clickable" :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc"
        @sort-changed="onSortingChanged" @row-clicked="onRowClick"
        show-empty hover no-local-sorting sort-icon-left striped>
        <template v-slot:empty>
          <pf-empty-table :isLoading="isLoading">{{ $t('No logs found') }}</pf-empty-table>
        </template>
        <template v-slot:cell(mac)="data">
          <router-link :to="{ path: `/node/${data.value}` }"><mac v-text="data.value"></mac></router-link>
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
import scroll100 from '@/directives/scroll-100'

export default {
  name: 'dhcp-option82-logs-search',
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
  directives: {
    scroll100
  },
  props: {
    searchableOptions: {
      type: Object,
      default: () => ({
        searchApiEndpoint: 'dhcp_option82s',
        defaultSortKeys: ['created_at', 'mac'],
        defaultSearchCondition: {
          op: 'and',
          values: [{
            op: 'or',
            values: [
              { field: 'mac', op: 'contains', value: null }
            ]
          }]
        },
        defaultRoute: { name: 'dhcpoption82s' }
      })
    },
    tableValues: {
      type: Array,
      default: () => []
    },
    storeName: {
      type: String,
      default: null
    }
  },
  data () {
    return {
      // Fields must match the database schema
      fields: [ // keys match with b-form-select
        {
          value: 'created_at',
          text: 'Created', // i18n defer
          types: [conditionType.DATETIME]
        },
        {
          value: 'mac',
          text: 'MAC Address', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'circuit_id_string',
          text: 'Circuit ID', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'host',
          text: 'Host', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'module',
          text: 'Module', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'option82_switch',
          text: 'Option82 Switch', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'port',
          text: 'Port', // i18n defer
          types: [conditionType.INTEGER]
        },
        {
          value: 'switch_id',
          text: 'Switch ID', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'vlan',
          text: 'VLAN', // i18n defer
          types: [conditionType.INTEGER]
        }
      ],
      columns: [
        {
          key: 'mac',
          label: 'MAC Address', // i18n defer
          required: true,
          sortable: true,
          visible: true
        },
        {
          key: 'circuit_id_string',
          label: 'Circuit ID String', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'host',
          label: 'Host', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'module',
          label: 'Module', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'option82_switch',
          label: 'Option82 Switch', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'port',
          label: 'Port', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'switch_id',
          label: 'Switch ID', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'vlan',
          label: 'DHCP Option 82 VLAN', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'created_at',
          label: 'Created At', // i18n defer
          sortable: true,
          visible: true,
          class: 'text-nowrap',
          formatter: formatter.datetimeIgnoreZero
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
              { field: 'mac', op: 'contains', value: quickCondition }
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
      this.$router.push({ name: 'dhcpoption82', params: { mac: item.mac } })
    }
  }
}
</script>
