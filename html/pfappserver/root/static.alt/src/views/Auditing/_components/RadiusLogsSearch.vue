<template>
  <b-card no-body>
    <pf-progress :active="isLoading"></pf-progress>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Search RADIUS Audit Logs'"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" quick-placeholder="Search by MAC or username"
      :fields="fields" :advanced-mode="advancedMode" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset"></pf-search>
    <div class="card-body">
      <b-row align-h="between" align-v="center">
        <b-col cols="auto" class="mr-auto">
          <b-dropdown size="sm" variant="link" no-caret>
            <template slot="button-content">
              <icon name="columns" v-b-tooltip.hover.right :title="$t('Visible Columns')"></icon>
            </template>
            <template v-for="column in columns" :key="column.key">
              <b-dropdown-item v-if="column.locked" disabled>
                <icon class="position-absolute mt-1" name="thumbtack"></icon>
                <span class="ml-4">{{column.label}}</span>
              </b-dropdown-item>
              <a v-else href="#" :disabled="column.locked" class="dropdown-item" @click.stop="toggleColumn(column)">
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
  name: 'RadiusLogsSearch',
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
        searchApiEndpoint: 'radius_audit_logs',
        defaultSortKeys: ['created_at', 'mac'],
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
        defaultRoute: { name: 'auditing' }
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
          value: 'user_name',
          text: 'Username',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'mac',
          text: 'MAC Address',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'profile',
          text: 'Connection Profile',
          types: [conditionType.CONNECTION_PROFILE]
        },
        {
          value: 'pf_domain',
          text: 'Domain',
          types: [conditionType.DOMAIN]
        },
        {
          value: 'node_status',
          text: 'Node Status',
          types: [conditionType.NODE_STATUS]
        },
        {
          value: 'realm',
          text: 'Realm',
          types: [conditionType.REALM]
        },
        {
          value: 'role',
          text: 'Role',
          types: [conditionType.ROLE]
        },
        {
          value: 'source',
          text: 'Source',
          types: [conditionType.SOURCE]
        },
        {
          value: 'switch_id',
          text: 'Switch Group',
          types: [conditionType.SWITCH_GROUP]
        },
        {
          value: 'is_phone',
          text: 'Is a Phone',
          types: [conditionType.YESNO]
        }
      ],
      columns: [
        {
          key: 'created_at',
          label: this.$i18n.t('Created At'),
          sortable: true,
          visible: true,
          formatter: formatter.datetimeIgnoreZero
        },
        {
          key: 'id',
          label: this.$i18n.t('ID'),
          sortable: true,
          visible: true,
          locked: false
        },
        {
          key: 'mac',
          label: this.$i18n.t('MAC Address'),
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
          key: 'auth_type',
          label: this.$i18n.t('Auth Type'),
          sortable: true,
          visible: false
        },
        {
          key: 'auto_reg',
          label: this.$i18n.t('Auto Reg'),
          sortable: true,
          visible: false
        },
        {
          key: 'calling_station_id',
          label: this.$i18n.t('Calling Station ID'),
          sortable: true,
          visible: false
        },
        {
          key: 'computer_name',
          label: this.$i18n.t('Computer Name'),
          sortable: true,
          visible: false
        },
        {
          key: 'eap_type',
          label: this.$i18n.t('EAP Type'),
          sortable: true,
          visible: false
        },
        {
          key: 'event_type',
          label: this.$i18n.t('Event Type'),
          sortable: true,
          visible: false
        },
        {
          key: 'ip',
          label: this.$i18n.t('IP Address'),
          sortable: true,
          visible: true
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
          sortable: true,
          visible: false
        },
        {
          key: 'profile',
          label: this.$i18n.t('Profile'),
          sortable: true,
          visible: false
        },
        {
          key: 'realm',
          label: this.$i18n.t('Realm'),
          sortable: true,
          visible: false
        },
        {
          key: 'reason',
          label: this.$i18n.t('Reason'),
          sortable: true,
          visible: false
        },
        {
          key: 'role',
          label: this.$i18n.t('Role'),
          sortable: true,
          visible: false
        },
        {
          key: 'source',
          label: this.$i18n.t('Source'),
          sortable: true,
          visible: false
        },
        {
          key: 'stripped_user_name',
          label: this.$i18n.t('Stripped User Name'),
          sortable: true,
          visible: false
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
          sortable: true,
          visible: false
        },
        {
          key: 'switch_mac',
          label: this.$i18n.t('Switch MAC'),
          sortable: true,
          visible: false
        },
        {
          key: 'switch_ip_address',
          label: this.$i18n.t('Switch IP Address'),
          sortable: true,
          visible: false
        },
        {
          key: 'called_station_id',
          label: this.$i18n.t('Called Station ID'),
          sortable: true,
          visible: false
        },
        {
          key: 'connection_type',
          label: this.$i18n.t('Connection Type'),
          sortable: true,
          visible: false
        },
        {
          key: 'ifindex',
          label: this.$i18n.t('IfIndex'),
          sortable: true,
          visible: false
        },
        {
          key: 'nas_identifier',
          label: this.$i18n.t('NAS ID'),
          sortable: true,
          visible: false
        },
        {
          key: 'nas_ip_address',
          label: this.$i18n.t('NAS IP Address'),
          sortable: true,
          visible: false
        },
        {
          key: 'nas_port',
          label: this.$i18n.t('NAS Port'),
          sortable: true,
          visible: false
        },
        {
          key: 'nas_port_id',
          label: this.$i18n.t('NAS Port ID'),
          sortable: true,
          visible: false
        },
        {
          key: 'nas_port_type',
          label: this.$i18n.t('NAS Port Type'),
          sortable: true,
          visible: false
        },
        {
          key: 'radius_source_ip_address',
          label: this.$i18n.t('RADIUS Source IP Address'),
          sortable: true,
          visible: false
        },
        {
          key: 'ssid',
          label: this.$i18n.t('SSID'),
          sortable: true,
          visible: false
        },
        {
          key: 'request_time',
          label: this.$i18n.t('Request Time'),
          sortable: true,
          visible: false
        },
        {
          key: 'radius_request',
          label: this.$i18n.t('RADIUS Request'),
          sortable: true,
          visible: false
        },
        {
          key: 'radius_reply',
          label: this.$i18n.t('RADIUS Reply'),
          sortable: true,
          visible: false
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
