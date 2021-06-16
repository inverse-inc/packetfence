<template>
  <b-card ref="container" no-body>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Search Nodes'"></h4>
    </b-card-header>
    <pf-search class="flex-shrink-0"
      :quick-with-fields="false"
      :quick-placeholder="$t('Search by MAC or owner')"
      save-search-namespace="nodes"
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
            <b-dropdown-item @click="applyBulkCloseSecurityEvent()">
              <icon class="position-absolute mt-1" name="ban"></icon>
              <span class="ml-4">{{ $t('Close Security Event') }}</span>
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
            <b-dropdown-item v-for="role in roles" :key="`role-${role.category_id}`" @click="applyBulkRole(role)">
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
            <b-dropdown-item v-for="role in roles" :key="`bypass_role-${role.category_id}`" @click="applyBulkBypassRole(role)">
              <span class="d-block" v-b-tooltip.hover.left.d300.window :title="role.notes">{{role.name}}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyBulkBypassRole({category_id: null})">
              <span class="d-block" v-b-tooltip.hover.left.d300.window :title="$t('Clear Bypass Role')">
                <icon class="position-absolute mt-1" name="trash-alt"></icon>
                <span class="ml-4"><em>{{ $t('None') }}</em></span>
              </span>
            </b-dropdown-item>
            <template v-if="$can.apply(null, ['read', 'security_events'])">
              <b-dropdown-divider></b-dropdown-divider>
              <b-dropdown-header>{{ $t('Apply Security Event') }}</b-dropdown-header>
              <b-dropdown-item v-for="security_event in security_events" :key="`security_event-${security_event.id}`" @click="applyBulkSecurityEvent(security_event)" v-b-tooltip.hover.left.d300 :title="security_event.id">
                <span>{{security_event.desc}}</span>
              </b-dropdown-item>
            </template>
          </b-dropdown>
          <b-dropdown size="sm" variant="link" :boundary="$refs.container" no-caret>
            <template v-slot:button-content>
              <icon name="columns" v-b-tooltip.hover.top.d300.window :title="$t('Visible Columns')"></icon>
            </template>
            <template v-for="(column, columnIndex) in columns">
              <b-dropdown-item :key="`dropdown-${columnIndex}`" v-if="column.locked" disabled>
                <icon class="position-absolute mt-1" name="thumbtack"></icon>
                <span class="ml-4">{{ $t(column.label) }}</span>
              </b-dropdown-item>
              <a :key="`icon-${columnIndex}`" v-else href="javascript:void(0)" :disabled="column.locked" class="dropdown-item" @click.stop="toggleColumn(column)">
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
              <b-pagination class="mr-3 my-0" align="right" v-model="currentPage" :per-page="pageSizeLimit" :total-rows="totalRows" :last-number="true" :disabled="isLoading"
                @change="onPageChange" />
              <base-button-export-csv filename="nodes.csv" :disabled="isLoading"
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
        <template v-slot:cell(actions)="item">
          <div class="text-nowrap">
            <b-form-checkbox :id="item.value" :value="item.item" v-model="selectValues" @click.stop="onToggleSelected($event, item.index)"></b-form-checkbox>
            <icon name="exclamation-triangle" class="ml-1" v-if="tableValues[item.index] && tableValues[item.index]._rowMessage" v-b-tooltip.hover.right :title="tableValues[item.index]._rowMessage"></icon>
          </div>
        </template>
        <template v-slot:cell(status)="item">
          <span v-b-tooltip.left.d300 :title="$t('registered')" v-if="item.value === 'reg'">
            <icon name="check-circle"/>
          </span>
          <span v-b-tooltip.left.d300 :title="$t('unregistered')" v-else-if="item.value === 'unreg'">
            <icon name="regular/times-circle"/>
          </span>
          <span v-b-tooltip.left.d300 :title="$t('pending')" v-else>
            <icon name="regular/dot-circle"/>
          </span>
        </template>
        <template v-slot:cell(online)="item">
          <span v-b-tooltip.right.d300 :title="$t('on')" v-if="item.value === 'on'">
            <icon name="circle" class="text-success"/>
          </span>
          <span v-b-tooltip.right.d300 :title="$t('off')" v-else-if="item.value === 'off'">
            <icon name="circle" class="text-danger"/>
          </span>
          <span v-b-tooltip.right.d300 :title="$t('unknown')" v-else>
            <icon name="question-circle" class="text-warning"/>
          </span>
        </template>
        <template v-slot:cell(mac)="item">
          <mac v-text="item.value"></mac>
        </template>
        <template v-slot:cell(pid)="item">
          <b-button variant="link" :to="{ name: 'user', params: { pid: item.value } }">{{ item.value }}</b-button>
        </template>
        <template v-slot:cell(device_score)="item">
          <pf-fingerbank-score :score="item.value"></pf-fingerbank-score>
        </template>
        <template v-slot:cell(buttons)="item">
          <span class="float-right text-nowrap text-right">
            <base-button-confirm
              size="sm" variant="outline-danger" class="my-1 mr-1" reverse
              :disabled="isLoading"
              :confirm="$t('Delete Node?')"
              @click="remove(item.item)"
            >{{ $t('Delete') }}</base-button-confirm>
          </span>
        </template>
        <template v-slot:empty>
          <pf-empty-table :is-loading="isLoading">{{ $t('No node found') }}</pf-empty-table>
        </template>
      </b-table>
    </div>
    <b-modal v-model="showBypassVlanModal" size="sm" centered id="bypassVlanModal" :title="$t('Bulk Apply Bypass VLAN')" @shown="focusBypassVlanInput">
      <b-form-group>
        <b-form-input ref="bypassVlanInput" v-model="bypassVlanString" type="text" :placeholder="$t('Enter a VLAN')"/>
        <b-form-text v-t="'Leave empty to clear bypass VLAN.'"></b-form-text>
      </b-form-group>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" @click="showBypassVlanModal=false">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" @click="applyBulkBypassVlan()">{{ $t('Apply') }}</b-button>
      </template>
    </b-modal>
  </b-card>
</template>

<script>
import {
  BaseButtonConfirm,
  BaseButtonExportCsv
} from '@/components/new/'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfMixinSelectable from '@/components/pfMixinSelectable'
import pfFingerbankScore from '@/components/pfFingerbankScore'
import pfFormToggle from '@/components/pfFormToggle'
import scroll100 from '@/directives/scroll-100'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import bytes from '@/utils/bytes'
import convert from '@/utils/convert'

export default {
  name: 'nodes-search',
  mixins: [
    pfMixinSelectable,
    pfMixinSearchable
  ],
  components: {
    BaseButtonConfirm,
    BaseButtonExportCsv,
    pfEmptyTable,
    pfFingerbankScore,
    pfFormToggle
  },
  directives: {
    scroll100
  },
  props: {
    storeName: { // from router
      type: String,
      default: '$_nodes'
    },
    searchableOptions: {
      type: Object,
      default: () => ({
        searchApiEndpoint: 'nodes',
        defaultSortKeys: ['mac'],
        defaultSortDesc: false,
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
      tableValues: [],
      requestPage: 1,
      currentPage: 1,
      pageSizeLimit: 10,
      showBypassVlanModal: false,
      bypassVlanString: null,
      /**
      *  Fields on which a search can be defined.
      *  The names must match the database schema.
      *  The keys must conform to the format of the b-form-select's options property.
      */
      fields: [ // keys match with b-form-select
        {
          value: 'tenant_id',
          text: 'Tenant', // i18n defer
          types: [conditionType.INTEGER]
        },
        {
          value: 'status',
          text: 'Status', // i18n defer
          types: [conditionType.NODE_STATUS],
          icon: 'power-off'
        },
        {
          value: 'mac',
          text: 'MAC Address', // i18n defer
          types: [conditionType.SUBSTRING],
          icon: 'id-card'
        },
        {
          value: 'bypass_role_id',
          text: 'Bypass Role', // i18n defer
          types: [conditionType.ROLE, conditionType.SUBSTRING],
          icon: 'project-diagram'
        },
        {
          value: 'bypass_vlan',
          text: 'Bypass VLAN', // i18n defer
          types: [conditionType.SUBSTRING],
          icon: 'project-diagram'
        },
        {
          value: 'computername',
          text: 'Computer Name', // i18n defer
          types: [conditionType.SUBSTRING],
          icon: 'desktop'
        },
        {
          value: 'locationlog.connection_type',
          text: 'Connection Type', // i18n defer
          types: [conditionType.CONNECTION_TYPE],
          icon: 'plug'
        },
        {
          value: 'detect_date',
          text: 'Detected Date', // i18n defer
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'regdate',
          text: 'Registered Date', // i18n defer
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'unregdate',
          text: 'Unregistered Date', // i18n defer
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'last_arp',
          text: 'Last ARP Date', // i18n defer
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'last_dhcp',
          text: 'Last DHCP Date', // i18n defer
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'last_seen',
          text: 'Last seen Date', // i18n defer
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'device_class',
          text: 'Device Class', // i18n defer
          types: [conditionType.SUBSTRING],
          icon: 'barcode'
        },
        {
          value: 'device_manufacturer',
          text: 'Device Manufacturer', // i18n defer
          types: [conditionType.SUBSTRING],
          icon: 'barcode'
        },
        {
          value: 'device_type',
          text: 'Device Type', // i18n defer
          types: [conditionType.SUBSTRING],
          icon: 'barcode'
        },
        {
          value: 'ip4log.ip',
          text: 'IPv4 Address', // i18n defer
          types: [conditionType.SUBSTRING],
          icon: 'project-diagram'
        },
        {
          value: 'ip6log.ip',
          text: 'IPv6 Address', // i18n defer
          types: [conditionType.SUBSTRING],
          icon: 'project-diagram'
        },
        {
          value: 'machine_account',
          text: 'Machine Account', // i18n defer
          types: [conditionType.SUBSTRING],
          icon: 'desktop'
        },
        {
          value: 'notes',
          text: 'Notes', // i18n defer
          types: [conditionType.SUBSTRING],
          icon: 'notes-medical'
        },
        {
          value: 'online',
          text: 'Online Status', // i18n defer
          types: [conditionType.ONLINE],
          icon: 'power-off'
        },
        {
          value: 'pid',
          text: 'Owner', // i18n defer
          types: [conditionType.SUBSTRING],
          icon: 'user'
        },
        {
          value: 'category_id',
          text: 'Role', // i18n defer
          types: [conditionType.ROLE, conditionType.SUBSTRING],
          icon: 'project-diagram'
        },
        {
          value: 'locationlog.switch',
          text: 'Source Switch Identifier', // i18n defer
          types: [conditionType.SUBSTRING],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.switch_ip',
          text: 'Source Switch IP', // i18n defer
          types: [conditionType.SWITCH_IP],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.switch_mac',
          text: 'Source Switch MAC', // i18n defer
          types: [conditionType.SUBSTRING],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.port',
          text: 'Source Switch Port', // i18n defer
          types: [conditionType.INTEGER],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.ifDesc',
          text: 'Source Switch Port Description', // i18n defer
          types: [conditionType.SUBSTRING],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.ssid',
          text: 'SSID', // i18n defer
          types: [conditionType.SUBSTRING],
          icon: 'wifi'
        },
        {
          value: 'user_agent',
          text: 'User Agent', // i18n defer
          types: [conditionType.SUBSTRING],
          icon: 'user-secret'
        },
        /* TODO - #3400, #4166
        {
          value: 'security_event.open_security_event_id',
          text: 'Security Event Open', // i18n defer
          types: [conditionType.SECURITY_EVENT],
          icon: 'exclamation-triangle'
        },
        {
          value: 'security_event.open_count',
          text: 'Security Event Open Count [Issue #3400]', // i18n defer
          types: [conditionType.INTEGER],
          icon: 'exclamation-triangle'
        },
        {
          value: 'security_event.close_security_event_id',
          text: 'Security Event Closed', // i18n defer
          types: [conditionType.SECURITY_EVENT],
          icon: 'exclamation-circle'
        },
        {
          value: 'security_event.close_count',
          text: 'Security Event Close Count [Issue #3400]', // i18n defer
          types: [conditionType.INTEGER],
          icon: 'exclamation-circle'
        },
        */
        {
          value: 'voip',
          text: 'VoIP', // i18n defer
          types: [conditionType.YESNO],
          icon: 'phone'
        },
        {
          value: 'autoreg',
          text: 'Auto Registration', // i18n defer
          types: [conditionType.YESNO],
          icon: 'magic'
        },
        {
          value: 'bandwidth_balance',
          text: 'Bandwidth Balance', // i18n defer
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
          label: 'Actions', // i18n defer
          locked: true,
          formatter: (value, key, item) => {
            return item.mac
          }
        },
        {
          key: 'tenant_id',
          label: 'Tenant', // i18n defer
          sortable: true
        },
        {
          key: 'status',
          label: 'Status', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'online',
          label: 'Online', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'mac',
          label: 'MAC Address', // i18n defer
          required: true,
          sortable: true,
          visible: true
        },
        {
          key: 'detect_date',
          label: 'Detected Date', // i18n defer
          sortable: true,
          formatter: formatter.datetimeIgnoreZero,
          class: 'text-nowrap'
        },
        {
          key: 'regdate',
          label: 'Registration Date', // i18n defer
          sortable: true,
          formatter: formatter.datetimeIgnoreZero,
          class: 'text-nowrap'
        },
        {
          key: 'unregdate',
          label: 'Unregistration Date', // i18n defer
          sortable: true,
          formatter: formatter.datetimeIgnoreZero,
          class: 'text-nowrap'
        },
        {
          key: 'computername',
          label: 'Computer Name', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'pid',
          label: 'Owner', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'ip4log.ip',
          label: 'IPv4 Address', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'ip6log.ip',
          label: 'IPv6 Address', // i18n defer
          sortable: true
        },
        {
          key: 'device_class',
          label: 'Device Class', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'device_manufacturer',
          label: 'Device Manufacturer', // i18n defer
          sortable: true
        },
        {
          key: 'device_score',
          label: 'Device Score', // i18n defer
          sortable: true
        },
        {
          key: 'device_type',
          label: 'Device Type', // i18n defer
          sortable: true
        },
        {
          key: 'device_version',
          label: 'Device Version', // i18n defer
          sortable: true
        },
        {
          key: 'dhcp6_enterprise',
          label: 'DHCPv6 Enterprise', // i18n defer
          sortable: true
        },
        {
          key: 'dhcp6_fingerprint',
          label: 'DHCPv6 Fingerprint', // i18n defer
          sortable: true
        },
        {
          key: 'dhcp_fingerprint',
          label: 'DHCP Fingerprint', // i18n defer
          sortable: true
        },
        {
          key: 'category_id',
          label: 'Role', // i18n defer
          sortable: true,
          visible: true,
          formatter: formatter.categoryId
        },
        {
          key: 'locationlog.connection_type',
          label: 'Connection Type', // i18n defer
          sortable: true
        },
        {
          key: 'locationlog.session_id',
          label: 'Session ID', // i18n defer
          sortable: true
        },
        {
          key: 'locationlog.switch',
          label: 'Switch Identifier', // i18n defer
          sortable: true
        },
        {
          key: 'locationlog.switch_ip',
          label: 'Switch IP Address', // i18n defer
          sortable: true
        },
        {
          key: 'locationlog.switch_mac',
          label: 'Switch MAC Address', // i18n defer
          sortable: true
        },
        {
          key: 'locationlog.port',
          label: 'Switch Port', // i18n defer
          sortable: true
        },
        {
          key: 'locationlog.ifDesc',
          label: 'Switch Port Description', // i18n defer
          sortable: true
        },
        {
          key: 'locationlog.ssid',
          label: 'SSID', // i18n defer
          sortable: true
        },
        {
          key: 'locationlog.vlan',
          label: 'VLAN', // i18n defer
          sortable: true
        },
        {
          key: 'bypass_vlan',
          label: 'Bypass VLAN', // i18n defer
          sortable: true
        },
        {
          key: 'bypass_role_id',
          label: 'Bypass Role', // i18n defer
          sortable: true,
          formatter: formatter.bypassRoleId
        },
        {
          key: 'notes',
          label: 'Notes', // i18n defer
          sortable: true
        },
        {
          key: 'voip',
          label: 'VoIP', // i18n defer
          sortable: true
        },
        {
          key: 'last_arp',
          label: 'Last ARP', // i18n defer
          sortable: true,
          formatter: formatter.datetimeIgnoreZero,
          class: 'text-nowrap'
        },
        {
          key: 'last_dhcp',
          label: 'Last DHCP', // i18n defer
          sortable: true,
          formatter: formatter.datetimeIgnoreZero,
          class: 'text-nowrap'
        },
        {
          key: 'last_seen',
          label: 'Last seen', // i18n defer
          sortable: true,
          formatter: formatter.datetimeIgnoreZero,
          class: 'text-nowrap'
        },
        {
          key: 'machine_account',
          label: 'Machine Account', // i18n defer
          sortable: true
        },
        {
          key: 'autoreg',
          label: 'Auto Registration', // i18n defer
          sortable: true
        },
        {
          key: 'bandwidth_balance',
          label: 'Bandwidth Balance', // i18n defer
          sortable: true,
          formatter: (value) => {
            return (value) ? `${bytes.toHuman(value, 2, true)}B` : ''
          }
        },
        {
          key: 'time_balance',
          label: 'Time Balance', // i18n defer
          sortable: true
        },
        {
          key: 'user_agent',
          label: 'User Agent', // i18n defer
          sortable: true
        },
        {
          key: 'security_event.open_security_event_id',
          label: 'Security Event Open', // i18n defer
          sortable: true,
          class: 'text-nowrap',
          formatter: (this.$can.apply(null, ['read', 'security_events']))
            ? formatter.securityEventIdsToDescCsv
            : formatter.noAdminRolePermission
        },
        /* TODO - #4166
        {
          key: 'security_event.open_count',
          label: 'Security Event Open Count', // i18n defer
          sortable: true,
          class: 'text-nowrap'
        },
        */
        {
          key: 'security_event.close_security_event_id',
          label: 'Security Event Closed', // i18n defer
          sortable: true,
          class: 'text-nowrap',
          formatter: (this.$can.apply(null, ['read', 'security_events']))
            ? formatter.securityEventIdsToDescCsv
            : formatter.noAdminRolePermission
        },
        /* TODO - #4166
        {
          key: 'security_event.close_count',
          label: 'Security Event Closed Count', // i18n defer
          sortable: true,
          class: 'text-nowrap'
        }
        */
        {
          key: 'buttons',
          label: '',
          locked: true
        }
      ]
    }
  },
  computed: {
    roles () {
      this.$store.dispatch('config/getRoles')
      return this.$store.state.config.roles
    },
    security_events () {
      this.$store.dispatch('config/getSecurityEvents')
      return this.$store.getters['config/sortedSecurityEvents'].filter(securityEvent => securityEvent.enabled === 'Y')
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
    onRowClick (item) {
      this.$router.push({ name: 'node', params: { mac: item.mac } })
    },
    applyBulkCloseSecurityEvent () {
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkCloseSecurityEvents`, { items: macs }).then(items => {
          let successCount = 0
          let skippedCount = 0
          let failedCount = 0
          items.forEach(item => {
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
            message: this.$i18n.tc('Closed security events on 1 node. | Closed security events on {nodeCount} nodes.', items.length, { nodeCount: items.length }),
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
          items.forEach(item => {
            let index = this.tableValues.findIndex(value => value.mac === item.mac)
            switch (item.status) {
              case 'success':
                successCount++
                this.tableValues[index].status = 'reg'
                break
              case 'skipped': skippedCount++
                break
              default: failedCount++
            }
            this.setRowVariant(index, convert.statusToVariant({ status: item.status }))
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.tc('Registered 1 node. | Registered {nodeCount} nodes.', items.length, { nodeCount: items.length }),
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
          items.forEach(item => {
            let index = this.tableValues.findIndex(value => value.mac === item.mac)
            switch (item.status) {
              case 'success':
                this.tableValues[index].status = 'unreg'
                successCount++
                break
              case 'skipped': skippedCount++
                break
              default: failedCount++
            }
            this.setRowVariant(index, convert.statusToVariant({ status: item.status }))
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.tc('Deregistered 1 node. | Deregistered {nodeCount} nodes.', items.length, { nodeCount: items.length }),
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
          items.forEach(item => {
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
            message: this.$i18n.tc('Reevaluated access on 1 node. | Reevaluated access on {nodeCount} nodes.', items.length, { nodeCount: items.length }),
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
          items.forEach(item => {
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
            message: this.$i18n.tc('Restarted switch port on 1 node. | Restarted switch port on {nodeCount} nodes.', items.length, { nodeCount: items.length }),
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
          items.forEach(item => {
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
            message: this.$i18n.tc('Refreshed fingerbank on 1 node. | Refreshed fingerbank on {nodeCount} nodes.', items.length, { nodeCount: items.length }),
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
          items.forEach(item => {
            let index = this.tableValues.findIndex(value => value.mac === item.mac)
            switch (item.status) {
              case 'success':
                this.tableValues[index].category_id = role.category_id
                successCount++
                break
              case 'skipped': skippedCount++
                break
              default: failedCount++
            }
            this.setRowVariant(index, convert.statusToVariant({ status: item.status }))
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.tc('Applied role on 1 node. | Applied role on {nodeCount} nodes.', items.length, { nodeCount: items.length }),
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
          items.forEach(item => {
            let index = this.tableValues.findIndex(value => value.mac === item.mac)
            switch (item.status) {
              case 'success':
                this.tableValues[index].bypass_category_id = role.category_id
                successCount++
                break
              case 'skipped': skippedCount++
                break
              default: failedCount++
            }
            this.setRowVariant(index, convert.statusToVariant({ status: item.status }))
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.tc('Applied bypass role on 1 node. | Applied bypass role on {nodeCount} nodes.', items.length, { nodeCount: items.length }),
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
        this.$store.dispatch(`${this.storeName}/bulkApplySecurityEvent`, { security_event_id: securityEvent.id, items: macs }).then(items => {
          let successCount = 0
          let skippedCount = 0
          let failedCount = 0
          items.forEach(item => {
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
            message: this.$i18n.tc('Applied security event on 1 node. | Applied security event on {nodeCount} nodes.', items.length, { nodeCount: items.length }),
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
          items.forEach(item => {
            let index = this.tableValues.findIndex(value => value.mac === item.mac)
            switch (item.status) {
              case 'success':
                this.tableValues[index].bypass_vlan = bypassVlan
                successCount++
                break
              case 'skipped': skippedCount++
                break
              default: failedCount++
            }
            this.setRowVariant(index, convert.statusToVariant({ status: item.status }))
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.tc('Applied bypass VLAN on 1 node. | Applied bypass VLAN on {nodeCount} nodes.', items.length, { nodeCount: items.length }),
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
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteNode`, item.mac).then(() => {
        this.onSearch()
      })
    }
  }
}
</script>
