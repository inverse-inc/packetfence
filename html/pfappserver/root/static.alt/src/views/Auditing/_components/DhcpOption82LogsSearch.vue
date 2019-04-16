<template>
  <b-card no-body>
    <pf-progress :active="isLoading"></pf-progress>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Search DHCP Option82 Logs'"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" quick-placeholder="Search by MAC"
      :fields="fields" :advanced-mode="advancedMode" :condition="condition"
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
      <b-table class="table-clickable" :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc"
        @sort-changed="onSortingChanged" @row-clicked="onRowClick"
        show-empty responsive hover no-local-sorting striped>
        <template slot="mac" slot-scope="log">
          <mac v-text="log.item.mac"></mac>
        </template>
        <template slot="empty">
          <pf-empty-table :isLoading="isLoading">{{ $t('No logs found') }}</pf-empty-table>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfProgress from '@/components/pfProgress'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfSearch from '@/components/pfSearch'
import pfFormToggle from '@/components/pfFormToggle'

export default {
  name: 'DhcpOption82LogsSearch',
  mixins: [
    pfMixinSearchable
  ],
  components: {
    pfProgress,
    pfEmptyTable,
    pfSearch,
    pfFormToggle
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
          value: 'mac',
          text: 'MAC Address',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'circuit_id_string',
          text: 'Circuit ID',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'host',
          text: 'Host',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'module',
          text: 'Module',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'option82_switch',
          text: 'Option82 Switch',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'port',
          text: 'Port',
          types: [conditionType.INTEGER]
        },
        {
          value: 'switch_id',
          text: 'Switch ID',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'vlan',
          text: 'VLAN',
          types: [conditionType.INTEGER]
        }
      ],
      columns: [
        {
          key: 'mac',
          label: this.$i18n.t('MAC Address'),
          sortable: true,
          visible: true
        },
        {
          key: 'circuit_id_string',
          label: this.$i18n.t('Circuit ID String'),
          sortable: true,
          visible: true,
          locked: false
        },
        {
          key: 'host',
          label: this.$i18n.t('Host'),
          sortable: true,
          visible: true
        },
        {
          key: 'module',
          label: this.$i18n.t('Module'),
          sortable: true,
          visible: true
        },
        {
          key: 'option82_switch',
          label: this.$i18n.t('Option82 Switch'),
          sortable: true,
          visible: true
        },
        {
          key: 'port',
          label: this.$i18n.t('Port'),
          sortable: true,
          visible: true
        },
        {
          key: 'switch_id',
          label: this.$i18n.t('Switch ID'),
          sortable: true,
          visible: true
        },
        {
          key: 'vlan',
          label: this.$i18n.t('DHCP Option 82 VLAN'),
          sortable: true,
          visible: true
        },
        {
          key: 'created_at',
          label: this.$i18n.t('Created At'),
          sortable: true,
          visible: true,
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
    onRowClick (item, index) {
      this.$router.push({ name: 'dhcpoption82', params: { mac: item.mac } })
    }
  }
}
</script>
