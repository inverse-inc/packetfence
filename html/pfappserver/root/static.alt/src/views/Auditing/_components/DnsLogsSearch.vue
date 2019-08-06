<template>
  <b-card no-body>
    <pf-progress :active="isLoading"></pf-progress>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Search DNS Audit Logs'"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" quick-placeholder="Search by MAC or IP" save-search-namespace="dnslogs"
      :fields="fields" :advanced-mode="advancedMode" :condition="condition" :storeName="storeName"
      @submit-search="onSearch" @reset-search="onReset"></pf-search>
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
              <pf-button-export-to-csv class="mb-3" filename="dnslogs.csv" :disabled="isLoading"
                :columns="columns" :data="items"
              />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table class="table-clickable" :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc"
        @sort-changed="onSortingChanged" @row-clicked="onRowClick"
        show-empty responsive hover no-local-sorting striped>
        <template slot="empty">
          <pf-empty-table :isLoading="isLoading">{{ $t('No logs found') }}</pf-empty-table>
        </template>
        <template slot="mac" slot-scope="data">
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

export default {
  name: 'DnsLogsSearch',
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
        searchApiEndpoint: 'dns_audit_logs',
        defaultSortKeys: ['created_at', 'ip', 'mac', 'qname', 'scope'],
        defaultSearchCondition: {
          op: 'and',
          values: [{
            op: 'or',
            values: [
              { field: 'mac', op: 'contains', value: null }
            ]
          }]
        },
        defaultRoute: { name: 'dnslogs' }
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
          text: 'Created',
          types: [conditionType.DATETIME]
        },
        {
          value: 'ip',
          text: 'IP Address',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'mac',
          text: 'MAC Address',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'qname',
          text: 'Dns request',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'qtype',
          text: 'DNS Type',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'scope',
          text: 'Scope',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'answer',
          text: 'DNS Answer',
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
          key: 'mac',
          label: this.$i18n.t('MAC Address'),
          sortable: true,
          visible: true
        },
        {
          key: 'qname',
          label: this.$i18n.t('Qname'),
          sortable: true,
          visible: true
        },
        {
          key: 'qtype',
          label: this.$i18n.t('Qtype'),
          sortable: true
        },
        {
          key: 'scope',
          label: this.$i18n.t('Scope'),
          sortable: true,
          visible: true
        },
        {
          key: 'answer',
          label: this.$i18n.t('Answer'),
          sortable: true,
          visible: true
        }
      ],
      sortBy: 'created_at',
      sortDesc: true
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
    onRowClick (item, index) {
      this.$router.push({ name: 'dnslog', params: { id: item.id } })
    }
  }
}
</script>
