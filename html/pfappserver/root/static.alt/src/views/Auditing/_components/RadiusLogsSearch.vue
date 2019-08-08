<template>
  <b-card no-body>
    <pf-progress :active="isLoading"></pf-progress>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Search RADIUS Audit Logs'"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" quick-placeholder="Search by MAC or username" save-search-namespace="radiuslogs"
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
              <pf-button-export-to-csv class="mb-3" filename="radiuslogs.csv" :disabled="isLoading"
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
        <template slot="auth_status" slot-scope="log">
          <b-badge pill :variant="(['Accept', 'CoA-ACK', 'Disconnect-ACK'].includes(log.item.auth_status)) ? 'success' : 'danger'" class="ml-1">{{ log.item.auth_status }}</b-badge>
        </template>
        <template slot="node_status" slot-scope="{ value }">
          <b-badge pill variant="success" v-if="value === 'reg'">{{ $t('Registered') }}</b-badge>
          <b-badge pill variant="warning" v-else-if="value === 'pending'">{{ $t('Pending') }}</b-badge>
          <b-badge pill variant="light" v-else>{{ $t('Unregistered') }}</b-badge>
        </template>
        <template slot="mac" slot-scope="{ value }">
          <router-link :to="{ path: `/node/${value}` }"><mac v-text="value"></mac></router-link>
        </template>
        <template slot="is_phone" slot-scope="{ value }">
          <icon v-if="parseInt(value) > 0" name="check"></icon>
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
  name: 'radius-logs-search',
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
        searchApiEndpoint: 'radius_audit_logs',
        defaultSortKeys: ['created_at', 'mac'],
        defaultSortDesc: true,
        defaultSearchCondition: {
          op: 'and',
          values: [{
            op: 'or',
            values: [
              { field: 'mac', op: 'contains', value: null },
              { field: 'user_name', op: 'contains', value: null }
            ]
          }]
        },
        defaultRoute: { name: 'radiuslogs' }
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
          value: 'auth_status',
          text: 'Auth Status',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'auth_type',
          text: 'Auth Type',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'radius_ip',
          text: 'Server IP',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'auto_reg',
          text: 'Auto Registration',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'called_station_id',
          text: 'Called Station ID',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'calling_station_id',
          text: 'Calling Station ID',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'computer_name',
          text: 'Computer name',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'profile',
          text: 'Connection Profile',
          types: [conditionType.CONNECTION_PROFILE]
        },
        {
          value: 'connection_type',
          text: 'Connection Type',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'created_at',
          text: 'Created',
          types: [conditionType.DATETIME]
        },
        {
          value: 'pf_domain',
          text: 'Domain',
          types: [conditionType.DOMAIN]
        },
        {
          value: 'eap_type',
          text: 'EAP Type',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'event_type',
          text: 'Event Type',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'ifindex',
          text: 'IfIndex',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'ip',
          text: 'IP Address',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'is_phone',
          text: 'Is a Phone',
          types: [conditionType.YESNO]
        },
        {
          value: 'mac',
          text: 'MAC Address',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'nas_identifier',
          text: 'NAS identifier',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'nas_ip_address',
          text: 'NAS IP Address',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'nas_port',
          text: 'NAS Port',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'nas_port_id',
          text: 'NAS Port ID',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'nas_port_type',
          text: 'NAS Port Type',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'node_status',
          text: 'Node Status',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'pf_domain',
          text: 'Domain',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'profile',
          text: 'Profile',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'radius_reply',
          text: 'RADIUS Reply',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'radius_request',
          text: 'RADIUS Request',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'radius_source_ip_address',
          text: 'RADIUS Source IP Address',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'realm',
          text: 'Realm',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'reason',
          text: 'Reason',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'request_time',
          text: 'Request Time',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'role',
          text: 'Role',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'source',
          text: 'Source',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'ssid',
          text: 'Wi-Fi Network SSID',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'stripped_user_name',
          text: 'Stripped User Name',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'switch_id',
          text: 'Switch ID',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'switch_ip_address',
          text: 'Switch IP Address',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'switch_mac',
          text: 'Switch MAC',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'user_name',
          text: 'User Name',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'uuid',
          text: 'Unique ID',
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
          key: 'auth_status',
          label: this.$i18n.t('Auth Status'),
          sortable: true,
          visible: true
        },
        {
          key: 'radius_ip',
          label: this.$i18n.t('Server IP'),
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
          key: 'auth_type',
          label: this.$i18n.t('Auth Type'),
          sortable: true
        },
        {
          key: 'auto_reg',
          label: this.$i18n.t('Auto Reg'),
          sortable: true
        },
        {
          key: 'calling_station_id',
          label: this.$i18n.t('Calling Station ID'),
          sortable: true
        },
        {
          key: 'computer_name',
          label: this.$i18n.t('Computer Name'),
          sortable: true
        },
        {
          key: 'eap_type',
          label: this.$i18n.t('EAP Type'),
          sortable: true
        },
        {
          key: 'event_type',
          label: this.$i18n.t('Event Type'),
          sortable: true
        },
        {
          key: 'ip',
          label: this.$i18n.t('IP Address'),
          sortable: true,
        },
        {
          key: 'is_phone',
          label: this.$i18n.t('Is a Phone'),
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
          key: 'pf_domain',
          label: this.$i18n.t('Domain'),
          sortable: true
        },
        {
          key: 'profile',
          label: this.$i18n.t('Profile'),
          sortable: true
        },
        {
          key: 'realm',
          label: this.$i18n.t('Realm'),
          sortable: true
        },
        {
          key: 'reason',
          label: this.$i18n.t('Reason'),
          sortable: true
        },
        {
          key: 'role',
          label: this.$i18n.t('Role'),
          sortable: true
        },
        {
          key: 'source',
          label: this.$i18n.t('Source'),
          sortable: true
        },
        {
          key: 'stripped_user_name',
          label: this.$i18n.t('Stripped User Name'),
          sortable: true
        },
        {
          key: 'user_name',
          label: this.$i18n.t('User Name'),
          sortable: true,
          visible: true
        },
        {
          key: 'uuid',
          label: this.$i18n.t('Unique ID'),
          sortable: true,
          visible: true
        },
        {
          key: 'switch_id',
          label: this.$i18n.t('Switch'),
          sortable: true
        },
        {
          key: 'switch_mac',
          label: this.$i18n.t('Switch MAC'),
          sortable: true
        },
        {
          key: 'switch_ip_address',
          label: this.$i18n.t('Switch IP Address'),
          sortable: true
        },
        {
          key: 'called_station_id',
          label: this.$i18n.t('Called Station ID'),
          sortable: true
        },
        {
          key: 'connection_type',
          label: this.$i18n.t('Connection Type'),
          sortable: true
        },
        {
          key: 'ifindex',
          label: this.$i18n.t('IfIndex'),
          sortable: true
        },
        {
          key: 'nas_identifier',
          label: this.$i18n.t('NAS ID'),
          sortable: true
        },
        {
          key: 'nas_ip_address',
          label: this.$i18n.t('NAS IP Address'),
          sortable: true,
          visible: true
        },
        {
          key: 'nas_port',
          label: this.$i18n.t('NAS Port'),
          sortable: true
        },
        {
          key: 'nas_port_id',
          label: this.$i18n.t('NAS Port ID'),
          sortable: true
        },
        {
          key: 'nas_port_type',
          label: this.$i18n.t('NAS Port Type'),
          sortable: true,
          visible: true
        },
        {
          key: 'radius_source_ip_address',
          label: this.$i18n.t('RADIUS Source IP Address'),
          sortable: true
        },
        {
          key: 'ssid',
          label: this.$i18n.t('SSID'),
          sortable: true
        },
        {
          key: 'request_time',
          label: this.$i18n.t('Request Time'),
          sortable: true
        },
        {
          key: 'radius_request',
          label: this.$i18n.t('RADIUS Request'),
          sortable: true
        },
        {
          key: 'radius_reply',
          label: this.$i18n.t('RADIUS Reply'),
          sortable: true
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
      this.$router.push({ name: 'radiuslog', params: { id: item.id } })
    }
  }
}
</script>
