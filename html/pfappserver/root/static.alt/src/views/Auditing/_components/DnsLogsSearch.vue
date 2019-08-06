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
          <b-dropdown size="sm" variant="link" :disabled="isLoading || selectValues.length === 0" no-caret no-flip>
            <template slot="button-content">
              <icon name="cog" v-b-tooltip.hover.top.d300 :title="$t('Bulk Actions')"></icon>
            </template>
            <b-dropdown-item @click="addToPassthroughs()">
              <icon class="position-absolute mt-1" name="door-open"></icon>
              <span class="ml-4">{{ $t('Add to Passthroughs') }}</span>
            </b-dropdown-item>
          </b-dropdown>
        </b-col>
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
        <template slot="mac" slot-scope="{ value }">
          <router-link :to="{ path: `/node/${value}` }"><mac v-text="value"></mac></router-link>
        </template>
        <div slot="answer" slot-scope="{ value }" v-html="value"></div>
        <template slot="empty">
          <pf-empty-table :isLoading="isLoading">{{ $t('No logs found') }}</pf-empty-table>
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
  name: 'dns-logs-search',
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
          text: this.$i18n.t('Created'),
          types: [conditionType.DATETIME]
        },
        {
          value: 'ip',
          text: this.$i18n.t('IP Address'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'mac',
          text: this.$i18n.t('MAC Address'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'qname',
          text: this.$i18n.t('DNS Request'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'qtype',
          text: this.$i18n.t('DNS Type'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'scope',
          text: this.$i18n.t('Scope'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'answer',
          text: this.$i18n.t('DNS Answer'),
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
