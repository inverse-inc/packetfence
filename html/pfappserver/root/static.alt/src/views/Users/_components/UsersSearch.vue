<template>
  <b-card no-body>
    <pf-progress :active="isLoading"></pf-progress>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Search Users'"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" :quick-placeholder="$t('Search by name or email')" save-search-namespace="users"
      :fields="fields" :storeName="storeName" :advanced-mode="advancedMode" :condition="condition"
      @submit-search="onSearch" @reset-search="onReset" @import-search="onImport"></pf-search>
    <div class="card-body">
      <b-row align-h="between" align-v="center">
        <b-col cols="auto" class="mr-auto">

          <b-dropdown size="sm" variant="link" :disabled="isLoading || selectValues.length === 0" no-caret>
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
            <b-dropdown-item @click="applyBulkRefreshFingerbank()">
              <icon class="position-absolute mt-1" name="retweet"></icon>
              <span class="ml-4">{{ $t('Refresh Fingerbank') }}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyBulkDelete()">
              <icon class="position-absolute mt-1" name="trash-alt"></icon>
              <span class="ml-4">{{ $t('Delete') }}</span>
            </b-dropdown-item>
            <b-dropdown-divider></b-dropdown-divider>

            <b-dropdown-header>{{ $t('Apply Role') }}</b-dropdown-header>
            <b-dropdown-item v-for="role in roles" :key="role.category_id" @click="applyBulkRole(role)">
              <span class="d-block" v-b-tooltip.hover.left.d300.window :title="role.notes">{{role.name}}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyBulkRole({category_id: null})" >
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
              <b-pagination class="mr-3" align="right" :per-page="pageSizeLimit" :total-rows="totalRows" v-model="requestPage" :disabled="isLoading"
                @input="onPageChange" />
              <pf-button-export-to-csv class="mb-3" filename="users.csv" :disabled="isLoading"
                :columns="columns" :data="items"
              />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table class="table-clickable" :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc" v-model="tableValues"
        @sort-changed="onSortingChanged" @row-clicked="onRowClick" @head-clicked="clearSelected"
        show-empty responsive hover no-local-sorting striped>
        <template slot="HEAD_actions" slot-scope="head">
          <b-form-checkbox id="checkallnone" v-model="selectAll" :disabled="isLoading" @change="onSelectAllChange"></b-form-checkbox>
          <b-tooltip target="checkallnone" placement="right" v-if="selectValues.length === tableValues.length">{{ $t('Select None [ALT+N]') }}</b-tooltip>
          <b-tooltip target="checkallnone" placement="right" v-else>{{ $t('Select All [ALT+A]') }}</b-tooltip>
        </template>
        <template slot="actions" slot-scope="data">
          <b-form-checkbox :disabled="isLoading" :id="data.value" :value="data.item" v-model="selectValues" @click.native.stop="onToggleSelected($event, data.index)"></b-form-checkbox>
          <!--
          <icon name="exclamation-triangle" class="ml-1" v-if="tableValues[data.index]._rowMessage" v-b-tooltip.hover.right.d300 :title="tableValues[data.index]._rowMessage"></icon>
          -->
        </template>
        <template slot="empty">
          <pf-empty-table :isLoading="isLoading">{{ $t('No user found') }}</pf-empty-table>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonExportToCsv from '@/components/pfButtonExportToCsv'
import pfProgress from '@/components/pfProgress'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfMixinSelectable from '@/components/pfMixinSelectable'
import pfFormToggle from '@/components/pfFormToggle'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export default {
  name: 'UsersSearch',
  mixins: [
    pfMixinSelectable,
    pfMixinSearchable
  ],
  components: {
    pfButtonDelete,
    pfButtonExportToCsv,
    pfProgress,
    pfEmptyTable,
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
        searchApiEndpoint: 'users',
        defaultSortKeys: ['pid'],
        defaultSearchCondition: {
          op: 'and',
          values: [{
            op: 'or',
            values: [
              { field: 'pid', op: 'contains', value: null },
              { field: 'email', op: 'contains', value: null }
            ]
          }]
        },
        defaultRoute: { name: 'users' }
      })
    }
  },
  data () {
    return {
      tableValues: Array,
      sortBy: 'pid',
      sortDesc: false,
      // Fields must match the database schema
      fields: [ // keys match with b-form-select
        {
          value: 'tenant_id',
          text: this.$i18n.t('Tenant'),
          types: [conditionType.INTEGER]
        },
        {
          value: 'pid',
          text: this.$i18n.t('PID'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'title',
          text: this.$i18n.t('Title'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'firstname',
          text: this.$i18n.t('Firstname'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'lastname',
          text: this.$i18n.t('Lastname'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'nickname',
          text: this.$i18n.t('Nickname'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'email',
          text: this.$i18n.t('Email'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'sponsor',
          text: this.$i18n.t('Sponsor'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'anniversary',
          text: this.$i18n.t('Anniversary'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'birthday',
          text: this.$i18n.t('Birthday'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'address',
          text: this.$i18n.t('Address'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'apartment_number',
          text: this.$i18n.t('Apartment Number'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'building_number',
          text: this.$i18n.t('Building Number'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'room_number',
          text: this.$i18n.t('Room Number'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'company',
          text: this.$i18n.t('Company'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'gender',
          text: this.$i18n.t('Gender'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'lang',
          text: this.$i18n.t('Language'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'notes',
          text: this.$i18n.t('Notes'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'portal',
          text: this.$i18n.t('Portal'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'psk',
          text: this.$i18n.t('PSK'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'source',
          text: this.$i18n.t('Source'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'cell_phone',
          text: this.$i18n.t('Cellular Phone Number'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'telephone',
          text: this.$i18n.t('Home Telephone Number'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'work_phone',
          text: this.$i18n.t('Work Telephone Number'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_1',
          text: this.$i18n.t('Custom Field #1'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_2',
          text: this.$i18n.t('Custom Field #2'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_3',
          text: this.$i18n.t('Custom Field #3'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_4',
          text: this.$i18n.t('Custom Field #4'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_5',
          text: this.$i18n.t('Custom Field #5'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_6',
          text: this.$i18n.t('Custom Field #6'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_7',
          text: this.$i18n.t('Custom Field #7'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_8',
          text: this.$i18n.t('Custom Field #8'),
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_9',
          text: this.$i18n.t('Custom Field #9'),
          types: [conditionType.SUBSTRING]
        }
      ],
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
          key: 'pid',
          label: this.$i18n.t('Username'),
          sortable: true,
          visible: true
        },
        {
          key: 'title',
          label: this.$i18n.t('Title'),
          sortable: true,
          visible: false
        },
        {
          key: 'firstname',
          label: this.$i18n.t('Firstname'),
          sortable: true,
          visible: true
        },
        {
          key: 'lastname',
          label: this.$i18n.t('Lastname'),
          sortable: true,
          visible: true
        },
        {
          key: 'nickname',
          label: this.$i18n.t('Nickname'),
          sortable: true,
          visible: false
        },
        {
          key: 'email',
          label: this.$i18n.t('Email'),
          sortable: true,
          visible: true
        },
        {
          key: 'sponsor',
          label: this.$i18n.t('Sponsor'),
          sortable: true,
          visible: false
        },
        {
          key: 'anniversary',
          label: this.$i18n.t('Anniversary'),
          sortable: true,
          visible: false
        },
        {
          key: 'birthday',
          label: this.$i18n.t('Birthday'),
          sortable: true,
          visible: false
        },
        {
          key: 'address',
          label: this.$i18n.t('Address'),
          sortable: true,
          visible: false
        },
        {
          key: 'apartment_number',
          label: this.$i18n.t('Apartment Number'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'building_number',
          label: this.$i18n.t('Building Number'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'room_number',
          label: this.$i18n.t('Room Number'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'company',
          label: this.$i18n.t('Company'),
          sortable: true,
          visible: false
        },
        {
          key: 'gender',
          label: this.$i18n.t('Gender'),
          sortable: true,
          visible: false
        },
        {
          key: 'lang',
          label: this.$i18n.t('Language'),
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
          key: 'portal',
          label: this.$i18n.t('Portal'),
          sortable: true,
          visible: false
        },
        {
          key: 'psk',
          label: this.$i18n.t('PSK'),
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
          key: 'cell_phone',
          label: this.$i18n.t('Cellular Phone Number'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'telephone',
          label: this.$i18n.t('Home Telephone Number'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'work_phone',
          label: this.$i18n.t('Work Telephone Number'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_1',
          label: this.$i18n.t('Custom Field #1'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_2',
          label: this.$i18n.t('Custom Field #2'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_3',
          label: this.$i18n.t('Custom Field #3'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_4',
          label: this.$i18n.t('Custom Field #4'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_5',
          label: this.$i18n.t('Custom Field #5'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_6',
          label: this.$i18n.t('Custom Field #6'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_7',
          label: this.$i18n.t('Custom Field #7'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_8',
          label: this.$i18n.t('Custom Field #8'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_9',
          label: this.$i18n.t('Custom Field #9'),
          sortable: true,
          visible: false,
          class: 'text-nowrap'
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
              { field: 'pid', op: 'contains', value: quickCondition },
              { field: 'email', op: 'contains', value: quickCondition }
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
      this.$router.push({ name: 'user', params: { pid: item.pid } })
    },
    applyBulkSecurityEvent (securityEvent) {
      const pids = this.selectValues.map(item => item.pid)
      if (pids.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkApplySecurityEvent`, { vid: securityEvent.vid, items: pids }).then(items => {
          let securityEventCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            if (item.security_events.length > 0) {
              securityEventCount += item.security_events.length
              this.setRowVariant(index, 'success')
            } else {
              this.setRowVariant(index, 'warning')
            }
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Applied {securityEventCount} security events for {userCount} users.', { securityEventCount: securityEventCount, userCount: this.selectValues.length }),
            success: securityEventCount
          })
        }).catch(() => {
          pids.forEach(pid => {
            let index = this.tableValues.findIndex(value => value.pid === pid)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    applyBulkCloseSecurityEvent () {
      const pids = this.selectValues.map(item => item.pid)
      if (pids.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkCloseSecurityEvents`, { items: pids }).then(items => {
          let securityEventCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            if (item.security_events.length > 0) {
              securityEventCount += item.security_events.length
              this.setRowVariant(index, 'success')
            } else {
              this.setRowVariant(index, 'warning')
            }
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Closed {securityEventCount} security events for {userCount} users.', { securityEventCount: securityEventCount, userCount: this.selectValues.length }),
            success: securityEventCount
          })
        }).catch(() => {
          pids.forEach(pid => {
            let index = this.tableValues.findIndex(value => value.pid === pid)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    applyBulkRegister () {
      const pids = this.selectValues.map(item => item.pid)
      if (pids.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkRegisterNodes`, { items: pids }).then(items => {
          let nodeCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            if (item.nodes.length > 0) {
              nodeCount += item.nodes.length
              this.setRowVariant(index, 'success')
            } else {
              this.setRowVariant(index, 'warning')
            }
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Registered {nodeCount} nodes for {userCount} users.', { nodeCount: nodeCount, userCount: this.selectValues.length }),
            success: nodeCount
          })
        }).catch(() => {
          pids.forEach(pid => {
            let index = this.tableValues.findIndex(value => value.pid === pid)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    applyBulkDeregister () {
      const pids = this.selectValues.map(item => item.pid)
      if (pids.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkDeregisterNodes`, { items: pids }).then(items => {
          let nodeCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            if (item.nodes.length > 0) {
              nodeCount += item.nodes.length
              this.setRowVariant(index, 'success')
            } else {
              this.setRowVariant(index, 'warning')
            }
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Deregistered {nodeCount} nodes for {userCount} users.', { nodeCount: nodeCount, userCount: this.selectValues.length }),
            success: nodeCount
          })
        }).catch(() => {
          pids.forEach(pid => {
            let index = this.tableValues.findIndex(value => value.pid === pid)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    applyBulkRole (role) {
      const pids = this.selectValues.map(item => item.pid)
      if (pids.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkApplyRole`, { category_id: role.category_id, items: pids }).then(items => {
          let nodeCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            if (item.nodes.length > 0) {
              nodeCount += item.nodes.length
              this.setRowVariant(index, 'success')
            } else {
              this.setRowVariant(index, 'warning')
            }
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Applied role on {nodeCount} nodes for {userCount} users.', { nodeCount: nodeCount, userCount: this.selectValues.length }),
            success: nodeCount
          })
        }).catch(() => {
          pids.forEach(pid => {
            let index = this.tableValues.findIndex(value => value.pid === pid)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    applyBulkBypassRole (role) {
      const pids = this.selectValues.map(item => item.pid)
      if (pids.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkApplyBypassRole`, { bypass_role_id: role.category_id, items: pids }).then(items => {
          let nodeCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            if (item.nodes.length > 0) {
              nodeCount += item.nodes.length
              this.setRowVariant(index, 'success')
            } else {
              this.setRowVariant(index, 'warning')
            }
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Applied bypass role on {nodeCount} nodes for {userCount} users.', { nodeCount: nodeCount, userCount: this.selectValues.length }),
            success: nodeCount
          })
        }).catch(() => {
          pids.forEach(pid => {
            let index = this.tableValues.findIndex(value => value.pid === pid)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    applyBulkReevaluateAccess () {
      const pids = this.selectValues.map(item => item.pid)
      if (pids.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkReevaluateAccess`, { items: pids }).then(items => {
          let nodeCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            if (item.nodes.length > 0) {
              nodeCount += item.nodes.length
              this.setRowVariant(index, 'success')
            } else {
              this.setRowVariant(index, 'warning')
            }
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Reevaluated access on {nodeCount} nodes for {userCount} users.', { nodeCount: nodeCount, userCount: this.selectValues.length }),
            success: nodeCount
          })
        }).catch(() => {
          pids.forEach(pid => {
            let index = this.tableValues.findIndex(value => value.pid === pid)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    applyBulkRefreshFingerbank () {
      const pids = this.selectValues.map(item => item.pid)
      if (pids.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkRefreshFingerbank`, { items: pids }).then(items => {
          let nodeCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            if (item.nodes.length > 0) {
              nodeCount += item.nodes.length
              this.setRowVariant(index, 'success')
            } else {
              this.setRowVariant(index, 'warning')
            }
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Refreshed fingerbank on {nodeCount} nodes for {userCount} users.', { nodeCount: nodeCount, userCount: this.selectValues.length }),
            success: nodeCount
          })
        }).catch(() => {
          pids.forEach(pid => {
            let index = this.tableValues.findIndex(value => value.pid === pid)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    },
    applyBulkDelete () {
      const pids = this.selectValues.map(item => item.pid)
      if (pids.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkDelete`, { items: pids }).then(items => {
          let nodeCount = 0
          items.forEach((item, _index, items) => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            this.setRowVariant(index, 'success')
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.t('Deleted {userCount} users.', { userCount: this.selectValues.length }),
            success: nodeCount
          })
          this.$refs.pfSearch.onSubmit() // resubmit search
        }).catch(() => {
          pids.forEach(pid => {
            let index = this.tableValues.findIndex(value => value.pid === pid)
            this.setRowVariant(index, 'danger')
          })
        })
      }
    }
  }
}
</script>
