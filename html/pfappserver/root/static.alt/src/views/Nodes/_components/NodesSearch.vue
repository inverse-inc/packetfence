<template>
  <b-card no-body>
    <pf-progress :active="isLoading"></pf-progress>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Search Nodes'"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" :quick-placeholder="$t('Search by MAC or owner')"  save-search-namespace="nodes"
      :fields="fields" :storeName="storeName" :advanced-mode="advancedMode" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset" @import-search="onImport"></pf-search>
    <div class="card-body">
      <b-row align-h="between" align-v="center">
        <b-col cols="auto" class="mr-auto">
          <b-dropdown size="sm" variant="link" :disabled="isLoading || selectValues.length === 0" no-caret no-flip>
            <template slot="button-content">
              <icon name="cog" v-b-tooltip.hover.top.d300 :title="$t('Bulk Actions')"></icon>
            </template>
            <b-dropdown-item @click="applyBulkCloseSecurityEvent()">
              <icon class="position-absolute mt-1" name="ban"></icon>
              <span class="ml-4">{{ $t('Clear Security Event') }}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyBulkRegister()">
              <icon class="position-absolute mt-1" name="plus-circle"></icon>
              <span class="ml-4">{{ $t('Register') }}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyBulkDeregister()">
              <icon class="position-absolute mt-1" name="minus-circle"></icon>
              <span class="ml-4">{{ $t('Deregister') }}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyBulkReevaluateAccess()">
              <icon class="position-absolute mt-1" name="sync"></icon>
              <span class="ml-4">{{ $t('Reevaluate Access') }}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyBulkRestartSwitchport()">
              <icon class="position-absolute mt-1" name="retweet"></icon>
              <span class="ml-4">{{ $t('Restart Switchport') }}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyBulkRefreshFingerbank()">
              <icon class="position-absolute mt-1" name="retweet"></icon>
              <span class="ml-4">{{ $t('Refresh Fingerbank') }}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="showBypassVlanModal = true">
              <icon class="position-absolute mt-1" name="project-diagram"></icon>
              <span class="ml-4">{{ $t('Apply Bypass VLAN') }}</span>
            </b-dropdown-item>
            <b-dropdown-divider></b-dropdown-divider>
            <b-dropdown-header>{{ $t('Apply Role') }}</b-dropdown-header>
            <b-dropdown-item v-for="role in roles" :key="role.category_id" @click="applyBulkRole(role)">
              <span class="d-block" v-b-tooltip.hover.left.d300.window :title="role.notes">{{role.name}}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyBulkRole({category_id: null})">
              <span class="d-block" v-b-tooltip.hover.left.d300.window :title="$t('Clear Role')">
                <icon class="position-absolute mt-1" name="trash-alt"></icon>
                <span class="ml-4"><em>{{ $t('None') }}</em></span>
              </span>
            </b-dropdown-item>
            <b-dropdown-divider></b-dropdown-divider>
            <b-dropdown-header>{{ $t('Apply Bypass Role') }}</b-dropdown-header>
            <b-dropdown-item v-for="role in roles" :key="role.category_id" @click="applyBulkBypassRole(role)">
              <span class="d-block" v-b-tooltip.hover.left.d300.window :title="role.notes">{{role.name}}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyBulkBypassRole({category_id: null})">
              <span class="d-block" v-b-tooltip.hover.left.d300.window :title="$t('Clear Bypass Role')">
                <icon class="position-absolute mt-1" name="trash-alt"></icon>
                <span class="ml-4"><em>{{ $t('None') }}</em></span>
              </span>
            </b-dropdown-item>
            <b-dropdown-divider></b-dropdown-divider>
            <b-dropdown-header>{{ $t('Apply Security Event') }}</b-dropdown-header>
            <b-dropdown-item v-for="security_event in security_events" v-if="security_event.enabled ==='Y'" :key="security_event.id" @click="applyBulkSecurityEvent(security_event)" v-b-tooltip.hover.left.d300 :title="security_event.id">
              <span>{{security_event.desc}}</span>
            </b-dropdown-item>
          </b-dropdown>
          <b-dropdown size="sm" variant="link" no-caret>
            <template slot="button-content">
              <icon name="columns" v-b-tooltip.hover.top.d300.window :title="$t('Visible Columns')"></icon>
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
              <b-pagination class="mr-3" align="right" v-model="requestPage" :per-page="pageSizeLimit" :total-rows="totalRows" :disabled="isLoading"
                @input="onPageChange" />
              <pf-button-export-to-csv class="mb-3" filename="nodes.csv" :disabled="isLoading"
                :searchableStoreName="searchableStoreName"
                :searchableOptions="searchableOptions"
                :columns="columns"
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
        <template slot="HEAD_actions" slot-scope="head">
          <input type="checkbox" id="checkallnone" v-model="selectAll" :disabled="isLoading" @change="onSelectAllChange" @click.stop>
          <b-tooltip target="checkallnone" placement="right" v-if="selectValues.length === tableValues.length">{{$t('Select None [ALT+N]')}}</b-tooltip>
          <b-tooltip target="checkallnone" placement="right" v-else>{{$t('Select All [ALT+A]')}}</b-tooltip>
        </template>
        <template slot="actions" slot-scope="data">
          <div class="text-nowrap">
            <input type="checkbox" :disabled="isLoading" :id="data.value" :value="data.item" v-model="selectValues" @click.stop="onToggleSelected($event, data.index)">
            <icon name="exclamation-triangle" class="ml-1" v-if="tableValues[data.index]._rowMessage" v-b-tooltip.hover.right.d300 :title="tableValues[data.index]._rowMessage"></icon>
          </div>
        </template>
        <template slot="status" slot-scope="data">
          <b-badge pill variant="success" v-if="data.value === 'reg'">{{ $t('registered') }}</b-badge>
          <b-badge pill variant="light" v-else>{{ $t('unregistered') }}</b-badge>
        </template>
        <template slot="online" slot-scope="data">
          <b-badge pill variant="success" v-if="data.value === 'on'">{{ $t('on') }}</b-badge>
          <b-badge pill variant="danger" v-else-if="data.value === 'off'">{{ $t('off') }}</b-badge>
          <b-badge pill variant="info" v-else>{{ $t('unknown') }}</b-badge>
        </template>
        <template slot="mac" slot-scope="data">
          <mac v-text="data.value"></mac>
        </template>
        <template slot="pid" slot-scope="data">
          <b-button variant="link" :to="`../user/${data.value}`">{{ data.value }}</b-button>
        </template>
        <template slot="device_score" slot-scope="data">
          <pf-fingerbank-score :score="data.value"></pf-fingerbank-score>
        </template>
        <template slot="empty">
          <pf-empty-table :isLoading="isLoading">{{ $t('No node found') }}</pf-empty-table>
        </template>
      </b-table>
    </div>
    <b-modal v-model="showBypassVlanModal" size="sm" centered id="bypassVlanModal" :title="$t('Bulk Apply Bypass VLAN')" @shown="focusBypassVlanInput">
      <b-form-group>
        <b-form-input ref="bypassVlanInput" v-model="bypassVlanString" type="text" :placeholder="$t('Enter a VLAN')"/>
        <b-form-text v-t="$t('Leave empty to clear bypass VLAN.')"></b-form-text>
      </b-form-group>
      <div slot="modal-footer">
        <b-button variant="secondary" class="mr-1" @click="showBypassVlanModal=false">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" @click="applyBulkBypassVlan()">{{ $t('Apply') }}</b-button>
      </div>
    </b-modal>
  </b-card>
</template>

<script>
import pfButtonExportToCsv from '@/components/pfButtonExportToCsv'
import pfEmptyTable from '@/components/pfEmptyTable'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfMixinSelectable from '@/components/pfMixinSelectable'
import pfFingerbankScore from '@/components/pfFingerbankScore'
import pfFormToggle from '@/components/pfFormToggle'
import pfProgress from '@/components/pfProgress'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import convert from '@/utils/convert'

export default {
  name: 'NodesSearch',
  mixins: [
    pfMixinSelectable,
    pfMixinSearchable
  ],
  components: {
    pfProgress,
    pfButtonExportToCsv,
    pfEmptyTable,
    pfFingerbankScore,
    pfFormToggle
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    searchableOptions: {
      type: Object,
      default: () => ({
        searchApiEndpoint: 'nodes',
        defaultSortKeys: ['mac'],
        defaultSearchCondition: {
          op: 'and',
          values: [{
            op: 'or',
            values: [
              { field: 'mac', op: 'contains', value: null },
              { field: 'pid', op: 'contains', value: null }
            ]
          }]
        },
        defaultRoute: { name: 'nodes' }
      })
    }
  },
  data () {
    return {
      tableValues: Array,
      sortBy: 'mac',
      sortDesc: false,
      /**
       *  Fields on which a search can be defined.
       *  The names must match the database schema.
       *  The keys must conform to the format of the b-form-select's options property.
       */
      fields: [ // keys match with b-form-select
        {
          value: 'tenant_id',
          text: this.$i18n.t('Tenant'),
          types: [conditionType.INTEGER]
        },
        {
          value: 'status',
          text: this.$i18n.t('Status'),
          types: [conditionType.NODE_STATUS],
          icon: 'power-off'
        },
        {
          value: 'mac',
          text: this.$i18n.t('MAC Address'),
          types: [conditionType.SUBSTRING],
          icon: 'id-card'
        },
        {
          value: 'bypass_role_id',
          text: this.$i18n.t('Bypass Role'),
          types: [conditionType.ROLE, conditionType.SUBSTRING],
          icon: 'project-diagram'
        },
        {
          value: 'bypass_vlan',
          text: this.$i18n.t('Bypass VLAN'),
          types: [conditionType.SUBSTRING],
          icon: 'project-diagram'
        },
        {
          value: 'computername',
          text: this.$i18n.t('Computer Name'),
          types: [conditionType.SUBSTRING],
          icon: 'desktop'
        },
        {
          value: 'locationlog.connection_type',
          text: this.$i18n.t('Connection Type'),
          types: [conditionType.CONNECTION_TYPE],
          icon: 'plug'
        },
        {
          value: 'detect_date',
          text: this.$i18n.t('Detected Date'),
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'regdate',
          text: this.$i18n.t('Registered Date'),
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'unregdate',
          text: this.$i18n.t('Unregistered Date'),
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'last_arp',
          text: this.$i18n.t('Last ARP Date'),
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'last_dhcp',
          text: this.$i18n.t('Last DHCP Date'),
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'device_class',
          text: this.$i18n.t('Device Class'),
          types: [conditionType.SUBSTRING],
          icon: 'barcode'
        },
        {
          value: 'device_manufacturer',
          text: this.$i18n.t('Device Manufacturer'),
          types: [conditionType.SUBSTRING],
          icon: 'barcode'
        },
        {
          value: 'device_type',
          text: this.$i18n.t('Device Type'),
          types: [conditionType.SUBSTRING],
          icon: 'barcode'
        },
        {
          value: 'ip4log.ip',
          text: this.$i18n.t('IPv4 Address'),
          types: [conditionType.SUBSTRING],
          icon: 'project-diagram'
        },
        {
          value: 'ip6log.ip',
          text: this.$i18n.t('IPv6 Address'),
          types: [conditionType.SUBSTRING],
          icon: 'project-diagram'
        },
        {
          value: 'machine_account',
          text: this.$i18n.t('Machine Account'),
          types: [conditionType.SUBSTRING],
          icon: 'desktop'
        },
        {
          value: 'notes',
          text: this.$i18n.t('Notes'),
          types: [conditionType.SUBSTRING],
          icon: 'notes-medical'
        },
        {
          value: 'online',
          text: this.$i18n.t('Online Status'),
          types: [conditionType.ONLINE],
          icon: 'power-off'
        },
        {
          value: 'pid',
          text: this.$i18n.t('Owner'),
          types: [conditionType.SUBSTRING],
          icon: 'user'
        },
        {
          value: 'category_id',
          text: this.$i18n.t('Role'),
          types: [conditionType.ROLE, conditionType.SUBSTRING],
          icon: 'project-diagram'
        },
        {
          value: 'locationlog.switch',
          text: this.$i18n.t('Source Switch Identifier'),
          types: [conditionType.SUBSTRING],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.switch_ip',
          text: this.$i18n.t('Source Switch IP'),
          types: [conditionType.SUBSTRING],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.switch_mac',
          text: this.$i18n.t('Source Switch MAC'),
          types: [conditionType.SUBSTRING],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.switch_port',
          text: this.$i18n.t('Source Switch Port'),
          types: [conditionType.INTEGER],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.switch_port_description',
          text: this.$i18n.t('Source Switch Port Description'),
          types: [conditionType.SUBSTRING],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.switch_description',
          text: this.$i18n.t('Source Switch Description'),
          types: [conditionType.SUBSTRING],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.ssid',
          text: this.$i18n.t('SSID'),
          types: [conditionType.SUBSTRING],
          icon: 'wifi'
        },
        {
          value: 'user_agent',
          text: this.$i18n.t('User Agent'),
          types: [conditionType.SUBSTRING],
          icon: 'user-secret'
        },
        {
          value: 'security_event.open_security_event_id',
          text: this.$i18n.t('Security Event Open'),
          types: [conditionType.SECURITY_EVENT],
          icon: 'exclamation-triangle'
        },
        {
          value: 'security_event.open_count',
          text: this.$i18n.t('Security Event Open Count [Issue #3400]'),
          types: [conditionType.INTEGER],
          icon: 'exclamation-triangle'
        },
        {
          value: 'security_event.close_security_event_id',
          text: this.$i18n.t('Security Event Closed'),
          types: [conditionType.SECURITY_EVENT],
          icon: 'exclamation-circle'
        },
        {
          value: 'security_event.close_count',
          text: this.$i18n.t('Security Event Close Count [Issue #3400]'),
          types: [conditionType.INTEGER],
          icon: 'exclamation-circle'
        },
        {
          value: 'voip',
          text: this.$i18n.t('VoIP'),
          types: [conditionType.YESNO],
          icon: 'phone'
        },
        {
          value: 'autoreg',
          text: this.$i18n.t('Auto Registration'),
          types: [conditionType.YESNO],
          icon: 'magic'
        },
        {
          value: 'bandwidth_balance',
          text: this.$i18n.t('Bandwidth Balance'),
          types: [conditionType.PREFIXMULTIPLE],
          icon: 'balance-scale'
        }
      ],
      /**
       * The columns that can be displayed in the results table.
       */
      columns: [
        {
          key: 'actions',
          label: this.$i18n.t('Actions'),
          sortable: false,
          visible: true,
          locked: true,
          formatter: (value, key, item) => {
            return item.mac
          }
        },
        {
          key: 'tenant_id',
          label: this.$i18n.t('Tenant'),
          sortable: true,
          visible: false
        },
        {
          key: 'status',
          label: this.$i18n.t('Status'),
          sortable: true,
          visible: true
        },
        {
          key: 'online',
          label: this.$i18n.t('Online/Offline'),
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
          key: 'detect_date',
          label: this.$i18n.t('Detected Date'),
          sortable: true,
          visible: false,
          formatter: formatter.datetimeIgnoreZero,
          class: 'text-nowrap'
        },
        {
          key: 'regdate',
          label: this.$i18n.t('Registration Date'),
          sortable: true,
          visible: false,
          formatter: formatter.datetimeIgnoreZero,
          class: 'text-nowrap'
        },
        {
          key: 'unregdate',
          label: this.$i18n.t('Unregistration Date'),
          sortable: true,
          visible: false,
          formatter: formatter.datetimeIgnoreZero,
          class: 'text-nowrap'
        },
        {
          key: 'computername',
          label: this.$i18n.t('Computer Name'),
          sortable: true,
          visible: true
        },
        {
          key: 'pid',
          label: this.$i18n.t('Owner'),
          sortable: true,
          visible: true
        },
        {
          key: 'ip4log.ip',
          label: this.$i18n.t('IPv4 Address'),
          sortable: true,
          visible: true
        },
        {
          key: 'ip6log.ip',
          label: this.$i18n.t('IPv6 Address'),
          sortable: true,
          visible: false
        },
        {
          key: 'device_class',
          label: this.$i18n.t('Device Class'),
          sortable: true,
          visible: true
        },
        {
          key: 'device_manufacturer',
          label: this.$i18n.t('Device Manufacturer'),
          sortable: true,
          visible: false
        },
        {
          key: 'device_score',
          label: this.$i18n.t('Device Score'),
          sortable: true,
          visible: false
        },
        {
          key: 'device_type',
          label: this.$i18n.t('Device Type'),
          sortable: true,
          visible: false
        },
        {
          key: 'device_version',
          label: this.$i18n.t('Device Version'),
          sortable: true,
          visible: false
        },
        {
          key: 'dhcp6_enterprise',
          label: this.$i18n.t('DHCPv6 Enterprise'),
          sortable: true,
          visible: false
        },
        {
          key: 'dhcp6_fingerprint',
          label: this.$i18n.t('DHCPv6 Fingerprint'),
          sortable: true,
          visible: false
        },
        {
          key: 'dhcp_fingerprint',
          label: this.$i18n.t('DHCP Fingerprint'),
          sortable: true,
          visible: false
        },
        {
          key: 'category_id',
          label: this.$i18n.t('Role'),
          sortable: true,
          visible: true,
          formatter: formatter.categoryId
        },
        {
          key: 'locationlog.connection_type',
          label: this.$i18n.t('Connection Type'),
          sortable: true,
          visible: false
        },
        {
          key: 'locationlog.session_id',
          label: this.$i18n.t('Session ID'),
          sortable: true,
          visible: false
        },
        {
          key: 'locationlog.switch',
          label: this.$i18n.t('Switch Identifier'),
          sortable: true,
          visible: false
        },
        {
          key: 'locationlog.switch_ip',
          label: this.$i18n.t('Switch IP Address'),
          sortable: true,
          visible: false
        },
        {
          key: 'locationlog.switch_mac',
          label: this.$i18n.t('Switch MAC Address'),
          sortable: true,
          visible: false
        },
        {
          key: 'locationlog.switch_port',
          label: this.$i18n.t('Switch Port'),
          sortable: true,
          visible: false
        },
        {
          key: 'locationlog.switch_port_description',
          label: this.$i18n.t('Switch Port Description'),
          sortable: true,
          visible: false
        },
        {
          key: 'locationlog.switch_description',
          label: this.$i18n.t('Switch Description'),
          sortable: true,
          visible: false
        },
        {
          key: 'locationlog.ssid',
          label: this.$i18n.t('SSID'),
          sortable: true,
          visible: false
        },
        {
          key: 'locationlog.vlan',
          label: this.$i18n.t('VLAN'),
          sortable: true,
          visible: false
        },
        {
          key: 'bypass_vlan',
          label: this.$i18n.t('Bypass VLAN'),
          sortable: true,
          visible: false
        },
        {
          key: 'bypass_role_id',
          label: this.$i18n.t('Bypass Role'),
          sortable: true,
          visible: false,
          formatter: formatter.bypassRoleId
        },
        {
          key: 'notes',
          label: this.$i18n.t('Notes'),
          sortable: true,
          visible: false
        },
        {
          key: 'voip',
          label: this.$i18n.t('VoIP'),
          sortable: true,
          visible: false
        },
        {
          key: 'last_arp',
          label: this.$i18n.t('Last ARP'),
          sortable: true,
          visible: false,
          formatter: formatter.datetimeIgnoreZero,
          class: 'text-nowrap'
        },
        {
          key: 'last_dhcp',
          label: this.$i18n.t('Last DHCP'),
          sortable: true,
          visible: false,
          formatter: formatter.datetimeIgnoreZero,
          class: 'text-nowrap'
        },
        {
          key: 'machine_account',
          label: this.$i18n.t('Machine Account'),
          sortable: true,
          visible: false
        },
        {
          key: 'autoreg',
          label: this.$i18n.t('Auto Registration'),
          sortable: true,
          visible: false
        },
        {
          key: 'bandwidth_balance',
          label: this.$i18n.t('Bandwidth Balance'),
          sortable: true,
          visible: false
        },
        {
          key: 'time_balance',
          label: this.$i18n.t('Time Balance'),
          sortable: true,
          visible: false
        },
        {
          key: 'user_agent',
          label: this.$i18n.t('User Agent'),
          sortable: true,
          visible: false
        },
        {
          key: 'security_event.open_security_event_id',
          label: this.$i18n.t('Security Event Open'),
          sortable: true,
          visible: false,
          class: 'text-nowrap',
          formatter: formatter.securityEventIdsToDescCsv
        },
        {
          key: 'security_event.open_count',
          label: this.$i18n.t('Security Event Open Count'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'security_event.close_security_event_id',
          label: this.$i18n.t('Security Event Closed'),
          sortable: true,
          visible: false,
          class: 'text-nowrap',
          formatter: formatter.securityEventIdsToDescCsv
        },
        {
          key: 'security_event.close_count',
          label: this.$i18n.t('Security Event Closed Count'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        }
      ],
      requestPage: 1,
      currentPage: 1,
      pageSizeLimit: 10,
      showBypassVlanModal: false,
      bypassVlanString: null
    }
  },
  computed: {
    roles () {
      this.$store.dispatch('config/getRoles')
      return this.$store.state.config.roles
    },
    security_events () {
      this.$store.dispatch('config/getSecurityEvents')
      return this.$store.getters['config/sortedSecurityEvents']
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
              { field: 'pid', op: 'contains', value: quickCondition }
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
      this.$router.push({ name: 'node', params: { mac: item.mac } })
    },
    applyBulkCloseSecurityEvent () {
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkCloseSecurityEvents`, { items: macs }).then(items => {
          let successCount = 0
          let skippedCount = 0
          let failedCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.mac === item.mac)
            switch (item.status) {
              case 'success': successCount++
                break
              case 'skipped': skippedCount++
                break
              default: failedCount++
            }
            this.setRowVariant(index, convert.statusToVariant({ status: item.status }))
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Closed security events on {nodeCount} nodes.', { nodeCount: items.length }),
            success: successCount,
            skipped: skippedCount,
            failed: failedCount
          })
        }).catch(() => {
          macs.forEach(mac => {
            let index = this.tableValues.findIndex(value => value.mac === mac)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    applyBulkRegister () {
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkRegisterNodes`, { items: macs }).then(items => {
          let successCount = 0
          let skippedCount = 0
          let failedCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.mac === item.mac)
            switch (item.status) {
              case 'success': successCount++
                break
              case 'skipped': skippedCount++
                break
              default: failedCount++
            }
            this.setRowVariant(index, convert.statusToVariant({ status: item.status }))
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Registered {nodeCount} nodes.', { nodeCount: items.length }),
            success: successCount,
            skipped: skippedCount,
            failed: failedCount
          })
        }).catch(() => {
          macs.forEach(mac => {
            let index = this.tableValues.findIndex(value => value.mac === mac)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    applyBulkDeregister () {
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkDeregisterNodes`, { items: macs }).then(items => {
          let successCount = 0
          let skippedCount = 0
          let failedCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.mac === item.mac)
            switch (item.status) {
              case 'success': successCount++
                break
              case 'skipped': skippedCount++
                break
              default: failedCount++
            }
            this.setRowVariant(index, convert.statusToVariant({ status: item.status }))
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Deregistered {nodeCount} nodes.', { nodeCount: items.length }),
            success: successCount,
            skipped: skippedCount,
            failed: failedCount
          })
        }).catch(() => {
          macs.forEach(mac => {
            let index = this.tableValues.findIndex(value => value.mac === mac)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    applyBulkReevaluateAccess () {
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkReevaluateAccess`, { items: macs }).then(items => {
          let successCount = 0
          let skippedCount = 0
          let failedCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.mac === item.mac)
            switch (item.status) {
              case 'success': successCount++
                break
              case 'skipped': skippedCount++
                break
              default: failedCount++
            }
            this.setRowVariant(index, convert.statusToVariant({ status: item.status }))
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Reevaluated access on {nodeCount} nodes.', { nodeCount: items.length }),
            success: successCount,
            skipped: skippedCount,
            failed: failedCount
          })
        }).catch(() => {
          macs.forEach(mac => {
            let index = this.tableValues.findIndex(value => value.mac === mac)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    applyBulkRestartSwitchport () {
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkRestartSwitchport`, { items: macs }).then(items => {
          let successCount = 0
          let skippedCount = 0
          let failedCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.mac === item.mac)
            switch (item.status) {
              case 'success': successCount++
                break
              case 'skipped': skippedCount++
                break
              default: failedCount++
            }
            this.setRowVariant(index, convert.statusToVariant({ status: item.status }))
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Restarted switch port on {nodeCount} nodes.', { nodeCount: items.length }),
            success: successCount,
            skipped: skippedCount,
            failed: failedCount
          })
        }).catch(() => {
          macs.forEach(mac => {
            let index = this.tableValues.findIndex(value => value.mac === mac)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    applyBulkRefreshFingerbank () {
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkRefreshFingerbank`, { items: macs }).then(items => {
          let successCount = 0
          let skippedCount = 0
          let failedCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.mac === item.mac)
            switch (item.status) {
              case 'success': successCount++
                break
              case 'skipped': skippedCount++
                break
              default: failedCount++
            }
            this.setRowVariant(index, convert.statusToVariant({ status: item.status }))
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Refreshed fingerbank on {nodeCount} nodes.', { nodeCount: items.length }),
            success: successCount,
            skipped: skippedCount,
            failed: failedCount
          })
        }).catch(() => {
          macs.forEach(mac => {
            let index = this.tableValues.findIndex(value => value.mac === mac)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    applyBulkRole (role) {
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkApplyRole`, { category_id: role.category_id, items: macs }).then(items => {
          let successCount = 0
          let skippedCount = 0
          let failedCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.mac === item.mac)
            switch (item.status) {
              case 'success': successCount++
                break
              case 'skipped': skippedCount++
                break
              default: failedCount++
            }
            this.setRowVariant(index, convert.statusToVariant({ status: item.status }))
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Applied role on {nodeCount} nodes.', { nodeCount: items.length }),
            success: successCount,
            skipped: skippedCount,
            failed: failedCount
          })
        }).catch(() => {
          macs.forEach(mac => {
            let index = this.tableValues.findIndex(value => value.mac === mac)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    applyBulkBypassRole (role) {
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkApplyBypassRole`, { bypass_role_id: role.category_id, items: macs }).then(items => {
          let successCount = 0
          let skippedCount = 0
          let failedCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.mac === item.mac)
            switch (item.status) {
              case 'success': successCount++
                break
              case 'skipped': skippedCount++
                break
              default: failedCount++
            }
            this.setRowVariant(index, convert.statusToVariant({ status: item.status }))
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Applied bypass role on {nodeCount} nodes.', { nodeCount: items.length }),
            success: successCount,
            skipped: skippedCount,
            failed: failedCount
          })
        }).catch(() => {
          macs.forEach(mac => {
            let index = this.tableValues.findIndex(value => value.mac === mac)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    applyBulkSecurityEvent (securityEvent) {
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkApplySecurityEvent`, { vid: securityEvent.vid, items: macs }).then(items => {
          let successCount = 0
          let skippedCount = 0
          let failedCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.mac === item.mac)
            switch (item.status) {
              case 'success': successCount++
                break
              case 'skipped': skippedCount++
                break
              default: failedCount++
            }
            this.setRowVariant(index, convert.statusToVariant({ status: item.status }))
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Applied security event on {nodeCount} nodes.', { nodeCount: items.length }),
            success: successCount,
            skipped: skippedCount,
            failed: failedCount
          })
        }).catch(() => {
          macs.forEach(mac => {
            let index = this.tableValues.findIndex(value => value.mac === mac)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    focusBypassVlanInput () {
      this.$refs.bypassVlanInput.focus()
    },
    applyBulkBypassVlan () {
      this.showBypassVlanModal = false
      const macs = this.selectValues.map(item => item.mac)
      const bypassVlan = (this.bypassVlanString) ? this.bypassVlanString : null
      if (macs.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkApplyBypassVlan`, { bypass_vlan: bypassVlan, items: macs }).then(items => {
          let successCount = 0
          let skippedCount = 0
          let failedCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.mac === item.mac)
            switch (item.status) {
              case 'success': successCount++
                break
              case 'skipped': skippedCount++
                break
              default: failedCount++
            }
            this.setRowVariant(index, convert.statusToVariant({ status: item.status }))
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Applied bypass VLAN on {nodeCount} nodes.', { nodeCount: items.length }),
            success: successCount,
            skipped: skippedCount,
            failed: failedCount
          })
        }).catch(() => {
          macs.forEach(mac => {
            let index = this.tableValues.findIndex(value => value.mac === mac)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    }
  }
}
</script>
