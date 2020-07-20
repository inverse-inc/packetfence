<template>
  <b-card ref="container" no-body>
    <pf-progress :active="isLoading"></pf-progress>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Search Users'"></h4>
    </b-card-header>
    <pf-search class="flex-shrink-0"
      :quick-with-fields="false"
      :quick-placeholder="$t('Search by name or email')"
      save-search-namespace="users"
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

          <b-dropdown size="sm" variant="link" :disabled="isLoading || selectValues.length === 0" no-caret>
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
            <b-dropdown-item v-for="role in roles" :key="`role-${role.category_id}`" @click="applyBulkRole(role)">
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
            <b-dropdown-item v-for="role in roles" :key="`bypass_role-${role.category_id}`" @click="applyBulkBypassRole(role)">
              <span class="d-block" v-b-tooltip.hover.left.d300.window :title="role.notes">{{role.name}}</span>
            </b-dropdown-item>
            <b-dropdown-item @click="applyBulkBypassRole({category_id: null})">
              <span class="d-block" v-b-tooltip.hover.left.d300.window :title="$t('Clear Bypass Role')">
                <icon class="position-absolute mt-1" name="trash-alt"></icon>
                <span class="ml-4"><em>{{ $t('None') }}</em></span>
              </span>
            </b-dropdown-item>
            <b-dropdown-divider></b-dropdown-divider>

            <b-dropdown-header v-can:read="'security_events'">{{ $t('Apply Security Event') }}</b-dropdown-header>
            <b-dropdown-item v-for="security_event in security_events" :key="security_event.id" @click="applyBulkSecurityEvent(security_event)" v-b-tooltip.hover.left.d300 :title="security_event.id">
              <span>{{security_event.desc}}</span>
            </b-dropdown-item>

          </b-dropdown>
          <b-dropdown size="sm" variant="link" :boundary="$refs.container" no-caret>
            <template v-slot:button-content>
              <icon name="columns" v-b-tooltip.hover.top.d300.window :title="$t('Visible Columns')"></icon>
            </template>
            <template v-for="column in columns">
              <b-dropdown-item :key="column.key" v-if="column.locked" disabled>
                <icon class="position-absolute mt-1" name="thumbtack"></icon>
                <span class="ml-4">{{ $t(column.label) }}</span>
              </b-dropdown-item>
              <a :key="column.key" v-else href="javascript:void(0)" :disabled="column.locked" class="dropdown-item" @click.stop="toggleColumn(column)">
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
              <b-pagination class="mr-3 my-0" align="right" :per-page="pageSizeLimit" :total-rows="totalRows" :last-number="true" v-model="currentPage" :disabled="isLoading"
                @change="onPageChange" />
              <pf-button-export-to-csv filename="users.csv" :disabled="isLoading"
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
          <b-form-checkbox id="checkallnone" v-model="selectAll" :disabled="isLoading" @change="onSelectAllChange"></b-form-checkbox>
          <b-tooltip target="checkallnone" placement="right" v-if="selectValues.length === tableValues.length">{{ $t('Select None [Alt + N]') }}</b-tooltip>
          <b-tooltip target="checkallnone" placement="right" v-else>{{ $t('Select All [Alt + A]') }}</b-tooltip>
        </template>
        <template v-slot:cell(actions)="item">
          <b-form-checkbox :disabled="isLoading" :id="item.value" :value="item.item" v-model="selectValues" @click.stop="onToggleSelected($event, item.index)"></b-form-checkbox>
          <!--
          <icon name="exclamation-triangle" class="ml-1" v-if="tableValues[item.index]._rowMessage" v-b-tooltip.hover.right.d300 :title="tableValues[item.index]._rowMessage"></icon>
          -->
        </template>
        <template v-slot:empty>
          <pf-empty-table :isLoading="isLoading">{{ $t('No user found') }}</pf-empty-table>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import pfButtonExportToCsv from '@/components/pfButtonExportToCsv'
import pfProgress from '@/components/pfProgress'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfMixinSelectable from '@/components/pfMixinSelectable'
import pfFormToggle from '@/components/pfFormToggle'
import scroll100 from '@/directives/scroll-100'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export default {
  name: 'users-search',
  mixins: [
    pfMixinSelectable,
    pfMixinSearchable
  ],
  components: {
    pfButtonExportToCsv,
    pfProgress,
    pfEmptyTable,
    pfFormToggle
  },
  directives: {
    scroll100
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
        defaultSortDesc: false,
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
      tableValues: [],
      // Fields must match the database schema
      fields: [ // keys match with b-form-select
        {
          value: 'tenant_id',
          text: 'Tenant', // i18n defer
          types: [conditionType.INTEGER]
        },
        {
          value: 'pid',
          text: 'PID', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'title',
          text: 'Title', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'firstname',
          text: 'Firstname', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'lastname',
          text: 'Lastname', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'nickname',
          text: 'Nickname', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'email',
          text: 'Email', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'sponsor',
          text: 'Sponsor', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'anniversary',
          text: 'Anniversary', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'birthday',
          text: 'Birthday', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'address',
          text: 'Address', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'apartment_number',
          text: 'Apartment Number', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'building_number',
          text: 'Building Number', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'room_number',
          text: 'Room Number', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'company',
          text: 'Company', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'gender',
          text: 'Gender', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'lang',
          text: 'Language', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'notes',
          text: 'Notes', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'portal',
          text: 'Portal', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'psk',
          text: 'PSK', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'source',
          text: 'Source', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'cell_phone',
          text: 'Cellular Phone Number', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'telephone',
          text: 'Home Telephone Number', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'work_phone',
          text: 'Work Telephone Number', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_1',
          text: 'Custom Field #1', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_2',
          text: 'Custom Field #2', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_3',
          text: 'Custom Field #3', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_4',
          text: 'Custom Field #4', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_5',
          text: 'Custom Field #5', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_6',
          text: 'Custom Field #6', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_7',
          text: 'Custom Field #7', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_8',
          text: 'Custom Field #8', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'custom_field_9',
          text: 'Custom Field #9', // i18n defer
          types: [conditionType.SUBSTRING]
        }
      ],
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
          key: 'pid',
          label: 'Username', // i18n defer
          required: true,
          sortable: true,
          visible: true
        },
        {
          key: 'title',
          label: 'Title', // i18n defer
          sortable: true
        },
        {
          key: 'firstname',
          label: 'Firstname', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'lastname',
          label: 'Lastname', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'nickname',
          label: 'Nickname', // i18n defer
          sortable: true
        },
        {
          key: 'email',
          label: 'Email', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'sponsor',
          label: 'Sponsor', // i18n defer
          sortable: true
        },
        {
          key: 'anniversary',
          label: 'Anniversary', // i18n defer
          sortable: true
        },
        {
          key: 'birthday',
          label: 'Birthday', // i18n defer
          sortable: true
        },
        {
          key: 'address',
          label: 'Address', // i18n defer
          sortable: true
        },
        {
          key: 'apartment_number',
          label: 'Apartment Number', // i18n defer
          sortable: true,
          class: 'text-nowrap'
        },
        {
          key: 'building_number',
          label: 'Building Number', // i18n defer
          sortable: true,
          class: 'text-nowrap'
        },
        {
          key: 'room_number',
          label: 'Room Number', // i18n defer
          sortable: true,
          class: 'text-nowrap'
        },
        {
          key: 'company',
          label: 'Company', // i18n defer
          sortable: true
        },
        {
          key: 'gender',
          label: 'Gender', // i18n defer
          sortable: true
        },
        {
          key: 'lang',
          label: 'Language', // i18n defer
          sortable: true
        },
        {
          key: 'notes',
          label: 'Notes', // i18n defer
          sortable: true
        },
        {
          key: 'portal',
          label: 'Portal', // i18n defer
          sortable: true
        },
        {
          key: 'psk',
          label: 'PSK', // i18n defer
          sortable: true
        },
        {
          key: 'source',
          label: 'Source', // i18n defer
          sortable: true
        },
        {
          key: 'cell_phone',
          label: 'Cellular Phone Number', // i18n defer
          sortable: true,
          class: 'text-nowrap'
        },
        {
          key: 'telephone',
          label: 'Home Telephone Number', // i18n defer
          sortable: true,
          class: 'text-nowrap'
        },
        {
          key: 'work_phone',
          label: 'Work Telephone Number', // i18n defer
          sortable: true,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_1',
          label: 'Custom Field #1', // i18n defer
          sortable: true,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_2',
          label: 'Custom Field #2', // i18n defer
          sortable: true,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_3',
          label: 'Custom Field #3', // i18n defer
          sortable: true,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_4',
          label: 'Custom Field #4', // i18n defer
          sortable: true,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_5',
          label: 'Custom Field #5', // i18n defer
          sortable: true,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_6',
          label: 'Custom Field #6', // i18n defer
          sortable: true,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_7',
          label: 'Custom Field #7', // i18n defer
          sortable: true,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_8',
          label: 'Custom Field #8', // i18n defer
          sortable: true,
          class: 'text-nowrap'
        },
        {
          key: 'custom_field_9',
          label: 'Custom Field #9', // i18n defer
          sortable: true,
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
    onRowClick (item) {
      this.$router.push({ name: 'user', params: { pid: item.pid } })
    },
    applyBulkSecurityEvent (securityEvent) {
      const pids = this.selectValues.map(item => item.pid)
      if (pids.length > 0) {
        this.$store.dispatch(`${this.storeName}/bulkApplySecurityEvent`, { vid: securityEvent.vid, items: pids }).then(items => {
          let securityEventCount = 0
          items.forEach(item => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            if (item.security_events.length > 0) {
              securityEventCount += item.security_events.length
              this.setRowVariant(index, 'success')
            } else {
              this.setRowVariant(index, 'warning')
            }
          })
          const securityEventString = this.$i18n.tc('Applied 1 security event | Applied {securityEventCount} security events', securityEventCount, { securityEventCount })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.tc('{securityEventString} for 1 user. | {securityEventString} for {userCount} users.', this.selectValues.length, { securityEventString, userCount: this.selectValues.length }),
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
          items.forEach(item => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            if (item.security_events.length > 0) {
              securityEventCount += item.security_events.length
              this.setRowVariant(index, 'success')
            } else {
              this.setRowVariant(index, 'warning')
            }
          })
          const securityEventString = this.$i18n.tc('Closed 1 security event | Closed {securityEventCount} security events', securityEventCount, { securityEventCount })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.tc('{securityEventString} for 1 user. | {securityEventString} for {userCount} users.', this.selectValues.length, { securityEventString, userCount: this.selectValues.length }),
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
          items.forEach(item => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            if (item.nodes.length > 0) {
              nodeCount += item.nodes.length
              this.setRowVariant(index, 'success')
            } else {
              this.setRowVariant(index, 'warning')
            }
          })
          const nodeString = this.$i18n.tc('Registered 1 node | Registered {nodeCount} nodes', nodeCount, { nodeCount })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.tc('{nodeString} for 1 user. | {nodeString} for {userCount} users.', this.selectValues.length, { nodeString, userCount: this.selectValues.length }),
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
          items.forEach(item => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            if (item.nodes.length > 0) {
              nodeCount += item.nodes.length
              this.setRowVariant(index, 'success')
            } else {
              this.setRowVariant(index, 'warning')
            }
          })
          const nodeString = this.$i18n.tc('Deregistered 1 node | Deregistered {nodeCount} nodes', nodeCount, { nodeCount })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.tc('{nodeString} for 1 user. | {nodeString} for {userCount} users.', this.selectValues.length, { nodeString, userCount: this.selectValues.length }),
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
          items.forEach(item => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            if (item.nodes.length > 0) {
              nodeCount += item.nodes.length
              this.setRowVariant(index, 'success')
            } else {
              this.setRowVariant(index, 'warning')
            }
          })
          const nodeString = this.$i18n.tc('Applied role on 1 node | Applied role on {nodeCount} nodes', nodeCount, { nodeCount })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.tc('{nodeString} for 1 user. | {nodeString} for {userCount} users.', this.selectValues.length, { nodeString, userCount: this.selectValues.length }),
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
          items.forEach(item => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            if (item.nodes.length > 0) {
              nodeCount += item.nodes.length
              this.setRowVariant(index, 'success')
            } else {
              this.setRowVariant(index, 'warning')
            }
          })
          const nodeString = this.$i18n.tc('Applied bypass role on 1 node | Applied bypass role on {nodeCount} nodes', nodeCount, { nodeCount })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.tc('{nodeString} for 1 user. | {nodeString} for {userCount} users.', this.selectValues.length, { nodeString, userCount: this.selectValues.length }),
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
          items.forEach(item => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            if (item.nodes.length > 0) {
              nodeCount += item.nodes.length
              this.setRowVariant(index, 'success')
            } else {
              this.setRowVariant(index, 'warning')
            }
          })
          const nodeString = this.$i18n.tc('Reevaluated access on 1 node | Reevaluated access on {nodeCount} nodes', nodeCount, { nodeCount })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.tc('{nodeString} for 1 user. | {nodeString} for {userCount} users.', this.selectValues.length, { nodeString, userCount: this.selectValues.length }),
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
          items.forEach(item => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            if (item.nodes.length > 0) {
              nodeCount += item.nodes.length
              this.setRowVariant(index, 'success')
            } else {
              this.setRowVariant(index, 'warning')
            }
          })
          const fingerbankString = this.$i18n.tc('Refreshed fingerbank on 1 node | Refreshed fingerbank on {nodeCount} nodes', nodeCount, { nodeCount })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.tc('{fingerbankString} for 1 user. | {fingerbankString} for {userCount} users.', this.selectValues.length, { fingerbankString, userCount: this.selectValues.length }),
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
          items.forEach(item => {
            let index = this.tableValues.findIndex(value => value.pid === item.pid)
            this.setRowVariant(index, 'success')
          })
          this.$store.dispatch('notification/info', {
            message: this.$i18n.tc('Deleted 1 user. | Deleted {userCount} users.', this.selectValues.length, { userCount: this.selectValues.length }),
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
