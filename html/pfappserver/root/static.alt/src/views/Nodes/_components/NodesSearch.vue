<template>
  <b-card no-body>
    <b-card-header>
      <div class="float-right"><toggle-button v-model="advancedMode">{{ $t('Advanced') }}</toggle-button></div>
      <h4 class="mb-0" v-t="'Search Nodes'"></h4>
    </b-card-header>
    <pf-search :fields="fields" :store="$store" :advanced-mode="advancedMode" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset"></pf-search>
    <div class="card-body">
      <b-row align-h="between" align-v="center">
        <b-col cols="auto" class="mr-auto">

          <b-dropdown size="sm" variant="link" :disabled="isLoading || checkedRows.length === 0" no-caret>
            <template slot="button-content">
              <icon name="cogs" v-b-tooltip.hover.right :title="$t('Actions')"></icon>
            </template>
            <b-dropdown-item @click="applyClearViolation()">
              <icon class="position-absolute mt-1" name="ban"></icon>
              <span class="ml-4">{{ $t('Clear Violation') }}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyRegister()">
              <icon class="position-absolute mt-1" name="plus-circle"></icon>
              <span class="ml-4">{{ $t('Register') }}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyDeregister()">
              <icon class="position-absolute mt-1" name="minus-circle"></icon>
              <span class="ml-4">{{ $t('Deregister') }}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyReevaluateAccess()">
              <icon class="position-absolute mt-1" name="sync"></icon>
              <span class="ml-4">{{ $t('Revaluate Access') }}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyRestartSwitchport()">
              <icon class="position-absolute mt-1" name="retweet"></icon>
              <span class="ml-4">{{ $t('Restart Switchport') }}</span>
            </b-dropdown-item>
            <b-dropdown-divider></b-dropdown-divider>
            <b-dropdown-header id="header1">{{ $t('Apply Role') }}</b-dropdown-header>
            <b-dropdown-item v-for="role in roles" :key="role.id" @click="applyRole(role)">
              <span>{{role.id}}</span>
            </b-dropdown-item>
            <b-dropdown-divider></b-dropdown-divider>
            <b-dropdown-header id="header2">{{ $t('Apply Bypass Role') }}</b-dropdown-header>
            <b-dropdown-item v-for="role in roles" :key="role.id" @click="applyBypassRole(role)">
              <span>{{role.id}}</span>
            </b-dropdown-item>
            <b-dropdown-divider></b-dropdown-divider>
            <b-dropdown-header id="header2">{{ $t('Apply Violation') }}</b-dropdown-header>
            <b-dropdown-item v-for="violation in violations" v-if="violation.enabled ==='Y'" :key="violation.id" @click="applyViolation(violation)">
              <span :id="violation.id" :title="violation.id">{{violation.desc}}</span>
              <b-tooltip :target="violation.id" placement="left">{{violation.id}}</b-tooltip>
            </b-dropdown-item>
          </b-dropdown>
          <b-dropdown size="sm" variant="link" :disabled="isLoading" no-caret>
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
        @sort-changed="onSortingChanged" @row-clicked="onRowClick" @head-clicked="clearChecked" hover no-local-sorting v-model="tableValues">
        <template slot="HEAD_actions" slot-scope="head">
          <input type="checkbox" v-model="checkedAll" @change="onCheckedAllChange" @click.stop>
        </template>
        <template slot="actions" slot-scope="data">
          <input type="checkbox" :id="data.value" :value="data.item" v-model="checkedRows" @change="onCheckedRowsChange" @click.stop>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import pfSearch from '@/components/pfSearch'
import ToggleButton from '@/components/ToggleButton'

export default {
  name: 'NodesSearch',
  components: {
    'pf-search': pfSearch,
    'toggle-button': ToggleButton
  },
  props: {
    namedSearch: String,
    tableValues: {
      type: Array,
      default: []
    },
    checkedRows: {
      type: Array,
      default: []
    },
    checkedAll: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      advancedMode: false,
      /**
       *  Fields on which a search can be defined.
       *  The names must match the database schema.
       *  The keys must conform to the format of the b-form-select's options property.
       */
      fields: [ // keys match with b-form-select
        {
          value: 'mac',
          text: 'MAC Address',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'computername',
          text: 'Computer Name',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'bypass_role_id',
          text: 'Bypass Role',
          types: [conditionType.ROLE, conditionType.SUBSTRING]
        },
        {
          value: 'locationlog.connection_type',
          text: 'Connection Type',
          types: [conditionType.CONNECTION_TYPE]
        },
        {
          value: 'category_id',
          text: 'Node Role',
          types: [conditionType.ROLE, conditionType.SUBSTRING]
        },
        {
          value: 'voip',
          text: 'VoIP',
          types: [conditionType.BOOL]
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
          key: 'last_ip',
          label: this.$i18n.t('IP Address'),
          sortable: true,
          visible: true
        },
        {
          key: 'tenant_name',
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
          key: 'dhcp_vendor',
          label: this.$i18n.t('DHCP Vendor'),
          sortable: true,
          visible: false
        },
        {
          key: 'category',
          label: this.$i18n.t('Role'),
          sortable: true,
          visible: true
        },
        {
          key: 'switch_id',
          label: this.$i18n.t('Switch Identifier'),
          sortable: true,
          visible: false
        },
        {
          key: 'switch_ip',
          label: this.$i18n.t('Switch IP Address'),
          sortable: true,
          visible: false
        },
        {
          key: 'switch_mac',
          label: this.$i18n.t('Switch MAC Address'),
          sortable: true,
          visible: false
        },
        {
          key: 'switch_port',
          label: this.$i18n.t('Switch Port'),
          sortable: true,
          visible: false
        },
        {
          key: 'switch_port_desc',
          label: this.$i18n.t('Switch Port Description'),
          sortable: true,
          visible: false
        },
        {
          key: 'switch_description',
          label: this.$i18n.t('Switch Description'),
          sortable: true,
          visible: false
        },
        {
          key: 'last_ssid',
          label: this.$i18n.t('SSID'),
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
          key: 'bypass_role',
          label: this.$i18n.t('Bypass Role'),
          sortable: true,
          visible: false
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
          key: 'sessionid',
          label: this.$i18n.t('Session ID'),
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
        }
      ],
      condition: null,
      requestPage: 1,
      currentPage: 1,
      pageSizeLimit: 10
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_nodes/isLoading']
    },
    sortBy () {
      return this.$store.state.$_nodes.searchSortBy
    },
    sortDesc () {
      return this.$store.state.$_nodes.searchSortDesc
    },
    visibleColumns () {
      return this.columns.filter(column => column.visible)
    },
    items () {
      return this.$store.state.$_nodes.items
    },
    totalRows () {
      return this.$store.state.$_nodes.searchMaxPageNumber * this.pageSizeLimit
    },
    roles () {
      return this.$store.state.config.roles
    },
    violations () {
      return this.$store.getters['config/sortedViolations']
    }
  },
  methods: {
    onSearch (condition) {
      let _this = this
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch('$_nodes/setSearchQuery', condition)
      this.$store.dispatch('$_nodes/search', this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
        _this.condition = condition
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
    },
    onReset () {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch('$_nodes/setSearchQuery', undefined) // reset search
      this.$store.dispatch('$_nodes/search', this.requestPage)
    },
    onPageSizeChange () {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch('$_nodes/setSearchPageSize', this.pageSizeLimit)
      this.$store.dispatch('$_nodes/search', this.requestPage)
    },
    onPageChange () {
      let _this = this
      this.$store.dispatch('$_nodes/search', this.requestPage).then(() => {
        _this.currentPage = _this.requestPage
      }).catch(() => {
        _this.requestPage = _this.currentPage
      })
    },
    onSortingChanged (params) {
      this.requestPage = 1 // reset to the first page
      this.$store.dispatch('$_nodes/setSearchSorting', params)
      this.$store.dispatch('$_nodes/search', this.requestPage)
    },
    toggleColumn (column) {
      column.visible = !column.visible
    },
    onRowClick (item, index) {
      this.$router.push({ name: 'node', params: { mac: item.mac } })
    },
    onCheckedRowsChange (item, index) {
      console.log(this.checkedRows)
    },
    onCheckedAllChange (item) {
      this.checkedRows = this.checkedAll ? this.tableValues : []
      console.log(this.checkedAll)
      console.log(this.tableValues)
    },
    clearChecked () {
      this.checkedAll = false
      this.checkedRows = []
    },
    applyClearViolation () {
      console.log(['applyClearViolation', this.checkedRows])
    },
    applyRegister () {
      console.log(['applyRegister', this.checkedRows])
    },
    applyDeregister () {
      console.log(['applyDeregister', this.checkedRows])
    },
    applyReevaluateAccess () {
      console.log(['applyReevaluateAccess', this.checkedRows])
    },
    applyRestartSwitchport () {
      console.log(['applyRestartSwitchport', this.checkedRows])
    },
    applyRole (role) {
      console.log(['applyRole', role, this.checkedRows])
    },
    applyBypassRole (role) {
      console.log(['applyBypassRole', role, this.checkedRows])
    },
    applyViolation (violation) {
      console.log(['applyViolation', violation, this.checkedRows])
    }
  },
  watch: {
    checkedRows (a, b) {
      this.checkedAll = (this.tableValues.length === a.length && a.length > 0)
    },
    condition (a, b) {
      if (a !== b) this.clearChecked()
    },
    requestPage (a, b) {
      if (a !== b) this.clearChecked()
    },
    currentPage (a, b) {
      if (a !== b) this.clearChecked()
    },
    pageSizeLimit (a, b) {
      if (a !== b) this.clearChecked()
    }
  },
  created () {
    this.$store.dispatch('$_nodes/search', this.requestPage)
    if (this.$store.state.config.roles.length === 0) {
      this.$store.dispatch('config/getRoles')
      this.$store.dispatch('config/getViolations')
      this.pageSizeLimit = this.$store.state.$_nodes.searchPageSize
      // Restore search parameters
      this.condition = this.$store.state.$_nodes.searchQuery
    }
  }
}
</script>
