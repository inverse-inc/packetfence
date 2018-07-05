<template>
  <b-card no-body>
    <b-card-header>
      <div class="float-right"><toggle-button v-model="advancedMode" :sync="true">{{ $t('Advanced') }}</toggle-button></div>
      <h4 class="mb-0" v-t="'Search Nodes'"></h4>
    </b-card-header>
    <pf-search :fields="fields" :store="$store" storeName="$_nodes" :advanced-mode="advancedMode" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset" @import-search="onImport"></pf-search>
    <div class="card-body">
      <b-row align-h="between" align-v="center">
        <b-col cols="auto" class="mr-auto">
          <b-dropdown size="sm" variant="link" :disabled="isLoading || selectValues.length === 0" no-caret>
            <template slot="button-content">
              <icon name="cogs" v-b-tooltip.hover.right :title="$t('Actions')"></icon>
            </template>
            <b-dropdown-item @click="applyBulkClearViolation()">
              <icon class="position-absolute mt-1" name="ban"></icon>
              <span class="ml-4">{{ $t('Clear Violation') }}</span>
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
              <span class="ml-4">{{ $t('Revaluate Access') }}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyBulkRestartSwitchport()">
              <icon class="position-absolute mt-1" name="retweet"></icon>
              <span class="ml-4">{{ $t('Restart Switchport') }}</span>
            </b-dropdown-item>
            <b-dropdown-divider></b-dropdown-divider>
            <b-dropdown-header>{{ $t('Apply Role') }}</b-dropdown-header>
            <b-dropdown-item v-for="role in roles" :key="role.category_id" @click="applyBulkRole(role)" v-b-tooltip.hover.left :title="role.notes">
              <span>{{role.name}}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyBulkRole({category_id: null})" v-b-tooltip.hover.left :title="$t('Clear Role')">
              <icon class="position-absolute mt-1" name="trash-alt"></icon>
              <span class="ml-4"><em>{{ $t('None') }}</em></span>
            </b-dropdown-item>
            <b-dropdown-divider></b-dropdown-divider>
            <b-dropdown-header>{{ $t('Apply Bypass Role') }}</b-dropdown-header>
            <b-dropdown-item v-for="role in roles" :key="role.category_id" @click="applyBulkBypassRole(role)" v-b-tooltip.hover.left :title="role.notes">
              <span>{{role.name}}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyBulkBypassRole({category_id: null})" v-b-tooltip.hover.left :title="$t('Clear Bypass Role')">
              <icon class="position-absolute mt-1" name="trash-alt"></icon>
              <span class="ml-4"><em>{{ $t('None') }}</em></span>
            </b-dropdown-item>
            <b-dropdown-divider></b-dropdown-divider>
            <b-dropdown-header>{{ $t('Apply Violation') }}</b-dropdown-header>
            <b-dropdown-item v-for="violation in violations" v-if="violation.enabled ==='Y'" :key="violation.id" @click="applyBulkViolation(violation)" v-b-tooltip.hover.left :title="violation.id">
              <span>{{violation.desc}}</span>
            </b-dropdown-item>
          </b-dropdown>
          <b-dropdown size="sm" variant="link" boundary="viewport" :disabled="isLoading" no-caret>
            <template slot="button-content">
              <icon name="columns" v-b-tooltip.hover.right :title="$t('Visible Columns')"></icon>
            </template>
            <b-dropdown-item v-for="column in columns" :key="column.key" @click="toggleColumn(column)" :disabled="column.locked">
              <icon class="position-absolute mt-1" name="thumbtack" v-show="column.visible" v-if="column.locked"></icon>
              <icon class="position-absolute mt-1" name="check" v-show="column.visible" v-else></icon>
              <span class="ml-4">{{column.label}}</span>
            </b-dropdown-item>
          </b-dropdown>
        </b-col>
        <b-col cols="auto">
          <b-container fluid>
            <b-row align-v="center">
              <b-form inline class="mb-0">
                <b-form-select class="mb-3 mr-3" size="sm" v-model="pageSizeLimit" :options="[10,25,50,100]" :disabled="isLoading"
                  @input="onPageSizeChange" />
              </b-form>
              <b-pagination align="right" v-model="requestPage" :per-page="pageSizeLimit" :total-rows="totalRows" :disabled="isLoading"
                @input="onPageChange" />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table stacked="sm" :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc"
        @sort-changed="onSortingChanged" @row-clicked="onRowClick" @head-clicked="clearSelected" hover no-local-sorting v-model="tableValues">
        <template slot="HEAD_actions" slot-scope="head">
          <input type="checkbox" id="checkallnone" v-model="selectAll" @change="onSelectAllChange" @click.stop>
          <b-tooltip target="checkallnone" placement="right" v-if="selectValues.length === tableValues.length">{{$t('Select None [ALT+N]')}}</b-tooltip>
          <b-tooltip target="checkallnone" placement="right" v-else>{{$t('Select All [ALT+A]')}}</b-tooltip>
        </template>
        <template slot="actions" slot-scope="data">
          <input type="checkbox" :id="data.value" :value="data.item" v-model="selectValues" @click.stop="onToggleSelected($event, data.index)">
          <icon name="exclamation-triangle" class="ml-1" v-if="tableValues[data.index]._message" v-b-tooltip.hover.right :title="tableValues[data.index]._message"></icon>
        </template>
        <template slot="status" slot-scope="data">
          <b-badge pill variant="success" v-if="data.value === 'reg'">{{ $t('registered') }}</b-badge>
          <b-badge pill variant="light" v-else>{{ $t('unregistered') }}</b-badge>
        </template>
        <template slot="online" slot-scope="data">
          <b-badge pill variant="success" v-if="data.value === 'on'">{{ $t('online') }}</b-badge>
          <b-badge pill variant="danger" v-else-if="data.value === 'off'">{{ $t('offline') }}</b-badge>
          <b-badge pill variant="info" v-else>{{ $t('unknown') }}</b-badge>
        </template>
        <template slot="device_score" slot-scope="data">
          <pf-fingerbank-score :score="data.value"></pf-fingerbank-score>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfMixinSelectable from '@/components/pfMixinSelectable'
import pfFingerbankScore from '@/components/pfFingerbankScore'

export default {
  name: 'NodesSearch',
  storeName: '$_nodes',
  mixins: [
    pfMixinSelectable,
    pfMixinSearchable
  ],
  pfMixinSearchableOptions: {
    searchApiEndpoint: 'nodes',
    defaultSortKeys: ['mac'],
    defaultSearchCondition: { op: 'and', values: [{ op: 'or', values: [{ field: 'mac', op: 'equals', value: null }] }] },
    defaultRoute: { name: 'nodes' }
  },
  components: {
    'pf-fingerbank-score': pfFingerbankScore
  },
  props: {
    tableValues: {
      type: Array,
      default: []
    }
  },
  data () {
    return {
      /**
       *  Fields on which a search can be defined.
       *  The names must match the database schema.
       *  The keys must conform to the format of the b-form-select's options property.
       */
      fields: [ // keys match with b-form-select
        {
          value: 'mac',
          text: this.$i18n.t('MAC Address'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'bypass_role_id',
          text: this.$i18n.t('Bypass Role'),
          types: [conditionType.ROLE, conditionType.SUBSTRING]
        },
        {
          value: 'bypass_vlan',
          text: this.$i18n.t('Bypass VLAN [?]'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'computername',
          text: this.$i18n.t('Computer Name'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'locationlog.connection_type',
          text: this.$i18n.t('Connection Type [?]'),
          types: [conditionType.CONNECTION_TYPE]
        },
        {
          value: 'device_class',
          text: this.$i18n.t('Device Class'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'device_manufacturer',
          text: this.$i18n.t('Device Manufacturer [?]'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'device_type',
          text: this.$i18n.t('Device Type'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'ip4log.ip',
          text: this.$i18n.t('IPv4 Address'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'ip6log.ip',
          text: this.$i18n.t('IPv6 Address'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'machine_account',
          text: this.$i18n.t('Machine Account'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'notes',
          text: this.$i18n.t('Notes'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'online',
          text: this.$i18n.t('Online Status'),
          types: [conditionType.ONLINE]
        },
        {
          value: 'pid',
          text: this.$i18n.t('Owner'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'category_id',
          text: this.$i18n.t('Role'),
          types: [conditionType.ROLE, conditionType.SUBSTRING]
        },
        {
          value: 'locationlog.switch',
          text: this.$i18n.t('Source Switch Identifier'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'locationlog.switch_ip',
          text: this.$i18n.t('Source Switch IP'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'locationlog.switch_mac',
          text: this.$i18n.t('Source Switch MAC'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'locationlog.ssid',
          text: this.$i18n.t('SSID'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'user_agent',
          text: this.$i18n.t('User Agent'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'violation.open_vid',
          text: this.$i18n.t('Violation'),
          types: [conditionType.VIOLATION]
        },
        {
          value: 'voip',
          text: this.$i18n.t('VoIP'),
          types: [conditionType.VOIP]
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
          visible: false
        },
        {
          key: 'regdate',
          label: this.$i18n.t('Registration Date'),
          sortable: true,
          visible: false
        },
        {
          key: 'unregdate',
          label: this.$i18n.t('Unregistration Date'),
          sortable: true,
          visible: false
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
          visible: true
        },
        {
          key: 'tenant_id',
          label: this.$i18n.t('Tenant'),
          sortable: true,
          visible: true
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
          visible: true
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
          formatter: (value, key, item) => {
            return this.roles.filter(role => role.category_id === item.category_id).map(role => role.name)
          }
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
          formatter: (value, key, item) => {
            return this.roles.filter(role => role.category_id === item.bypass_role_id).map(role => role.name)
          }
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
          visible: false
        },
        {
          key: 'last_dhcp',
          label: this.$i18n.t('Last DHCP'),
          sortable: true,
          visible: false
        },
        {
          key: 'machine_account',
          label: this.$i18n.t('Machine Account'),
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
          key: 'violation.open_vid',
          label: this.$i18n.t('Violation Open'),
          sortable: true,
          visible: false,
          formatter: (value, key, item) => {
            return this.violations.filter(violation => violation.id === item['violation.open_vid']).map(violation => violation.desc)
          }
        },
        {
          key: 'violation.open_count',
          label: this.$i18n.t('Violation Count'),
          sortable: true,
          visible: false
        }
      ],
      requestPage: 1,
      currentPage: 1,
      pageSizeLimit: 10
    }
  },
  computed: {
    roles () {
      return this.$store.state.config.roles
    },
    violations () {
      return this.$store.getters['config/sortedViolations']
    }
  },
  methods: {
    pfMixinSearchableAdvancedMode (condition) {
      return (condition.values.length > 1 || condition.values[0].values.length > 1)
    },
    onRowClick (item, index) {
      this.$router.push({ name: 'node', params: { mac: item.mac } })
    },
    applyBulkClearViolation () {
      const _this = this
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        this.$store.dispatch(`${this.$options.storeName}/clearViolationBulkNodes`, {items: macs}).then(response => {
          response.items.forEach(function (item, index, items) {
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, status: item.status})
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_MESSAGE`, {index: index, message: item.message})
          })
        }).catch(() => {
          macs.forEach(function (mac, i) {
            let index = _this.tableValues.findIndex(node => node.mac === mac)
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, variant: 'danger'})
          })
        })
      }
    },
    applyBulkRegister () {
      const _this = this
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        this.$store.dispatch(`${this.$options.storeName}/registerBulkNodes`, {items: macs}).then(response => {
          response.items.forEach(function (item, index, items) {
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, status: item.status})
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_MESSAGE`, {index: index, message: item.message})
          })
        }).catch(() => {
          macs.forEach(function (mac, i) {
            let index = _this.tableValues.findIndex(node => node.mac === mac)
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, variant: 'danger'})
          })
        })
      }
    },
    applyBulkDeregister () {
      const _this = this
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        this.$store.dispatch(`${this.$options.storeName}/deregisterBulkNodes`, {items: macs}).then(response => {
          response.items.forEach(function (item, index, items) {
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, status: item.status})
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_MESSAGE`, {index: index, message: item.message})
          })
        }).catch(() => {
          macs.forEach(function (mac, i) {
            let index = _this.tableValues.findIndex(node => node.mac === mac)
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, variant: 'danger'})
          })
        })
      }
    },
    applyBulkReevaluateAccess () {
      const _this = this
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        this.$store.dispatch(`${this.$options.storeName}/reevaluateAccessBulkNodes`, {items: macs}).then(response => {
          response.items.forEach(function (item, index, items) {
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, status: item.status})
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_MESSAGE`, {index: index, message: item.message})
          })
        }).catch(() => {
          macs.forEach(function (mac, i) {
            let index = _this.tableValues.findIndex(node => node.mac === mac)
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, variant: 'danger'})
          })
        })
      }
    },
    applyBulkRestartSwitchport () {
      const _this = this
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        this.$store.dispatch(`${this.$options.storeName}/restartSwitchportBulkNodes`, {items: macs}).then(response => {
          response.items.forEach(function (item, index, items) {
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, status: item.status})
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_MESSAGE`, {index: index, message: item.message})
          })
        }).catch(() => {
          macs.forEach(function (mac, i) {
            let index = _this.tableValues.findIndex(node => node.mac === mac)
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, variant: 'danger'})
          })
        })
      }
    },
    applyBulkRole (role) {
      const _this = this
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        macs.forEach(function (mac, i) {
          let index = _this.tableValues.findIndex(node => node.mac === mac)
          _this.$store.dispatch(`${_this.$options.storeName}/roleNode`, {mac: mac, category_id: role.category_id}).then(response => {
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, status: response.status})
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_MESSAGE`, {index: index, message: response.message})
          }).catch(() => {
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, variant: 'danger'})
          })
        })
      }
    },
    applyBulkBypassRole (role) {
      const _this = this
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        macs.forEach(function (mac, i) {
          let index = _this.tableValues.findIndex(node => node.mac === mac)
          _this.$store.dispatch(`${_this.$options.storeName}/bypassRoleNode`, {mac: mac, bypass_role_id: role.category_id}).then(response => {
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, status: response.status})
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_MESSAGE`, {index: index, message: response.message})
          }).catch(() => {
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, variant: 'danger'})
          })
        })
      }
    },
    applyBulkViolation (violation) {
      const _this = this
      const macs = this.selectValues.map(item => item.mac)
      if (macs.length > 0) {
        this.$store.dispatch(`${this.$options.storeName}/applyViolationBulkNodes`, {items: macs, vid: violation.id}).then(response => {
          response.items.forEach(function (item, index, items) {
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, status: item.status})
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_MESSAGE`, {index: index, message: item.message})
          })
        }).catch(() => {
          macs.forEach(function (mac, i) {
            let index = _this.tableValues.findIndex(node => node.mac === mac)
            _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, variant: 'danger'})
          })
        })
      }
    }
  },
  watch: {
    selectValues (a, b) {
      const _this = this
      const selectValues = this.selectValues
      this.tableValues.forEach(function (item, index, items) {
        if (selectValues.includes(item)) {
          _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, variant: 'info'})
        } else {
          _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_VARIANT`, {index: index, variant: ''})
          _this.$store.commit(`${_this.$options.storeName}_searchable/ROW_MESSAGE`, {index: index, message: ''})
        }
      })
    }
  },
  created () {
    this.$store.dispatch('config/getRoles')
    this.$store.dispatch('config/getViolations')
  }
}
</script>
