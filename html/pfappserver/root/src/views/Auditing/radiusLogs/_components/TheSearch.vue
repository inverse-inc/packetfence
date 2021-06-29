<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">
        {{ $t('RADIUS Audit Logs') }}
      </h4>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch" />
      <b-table ref="tableRef"
        :busy="isLoading"
        :hover="items.length > 0"
        :items="items"
        :fields="visibleColumns"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        @sort-changed="setSort"
        @row-clicked="goToItem"
        class="mb-0"
        show-empty
        no-local-sorting
        sort-icon-left
        fixed
        striped
        selectable
        @row-selected="onRowSelected"
      >
        <template #empty>
          <slot name="emptySearch" v-bind="{ isLoading }">
            <base-table-empty :is-loading="isLoading">{{ $t('No results found') }}</base-table-empty>
          </slot>
        </template>
        <template #head(selected)>
          <span @click.stop.prevent="onAllSelected">
            <template v-if="selected.length > 0">
              <icon name="check-square" class="bg-white text-success" scale="1.125" />
            </template>
            <template v-else>
              <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
            </template>
          </span>
        </template>
        <template #cell(selected)="{ index, rowSelected }">
          <span @click.stop="onItemSelected(index)">
            <template v-if="rowSelected">
              <icon name="check-square" class="bg-white text-success" scale="1.125" />
            </template>
            <template v-else>
              <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
            </template>
          </span>
        </template>
        <template #head(buttons)>
          <base-search-input-columns
            :disabled="isLoading"
            :value="columns"
            @input="setColumns"
          />
        </template>
        <template #cell(auth_status)="log">
          <b-badge pill :variant="(['Accept', 'CoA-ACK', 'Disconnect-ACK'].includes(log.item.auth_status)) ? 'success' : 'danger'" class="ml-1">{{ log.item.auth_status }}</b-badge>
        </template>
        <template #cell(node_status)="{ value }">
          <b-badge pill variant="success" v-if="value === 'reg'">{{ $t('Registered') }}</b-badge>
          <b-badge pill variant="warning" v-else-if="value === 'pending'">{{ $t('Pending') }}</b-badge>
          <b-badge pill variant="light" v-else>{{ $t('Unregistered') }}</b-badge>
        </template>
        <template #cell(mac)="{ value }">
          <router-link :to="{ path: `/node/${value}` }"><mac v-text="value"></mac></router-link>
        </template>
        <template #cell(is_phone)="{ value }">
          <icon v-if="parseInt(value) > 0" name="check"></icon>
        </template>
      </b-table>
      <b-container fluid v-if="selected.length"
        class="mt-3 p-0">
        <b-dropdown variant="outline-primary" toggle-class="text-decoration-none">
          <template #button-content>
            {{ $t('{num} selected', { num: selected.length }) }}
          </template>
          <b-dropdown-item @click="onBulkExport">{{ $t('Export to CSV') }}</b-dropdown-item>
        </b-dropdown>
      </b-container>
    </div>
  </b-card>
</template>
<script>
import {
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty
} from '@/components/new/'

const components = {
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty
}

import { ref, toRefs } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import { useRouter } from '../_router'
import { useSearch } from '../_search'

const setup = (props, context) => {

  const search = useSearch()
  const {
    items,
    visibleColumns
  } = toRefs(search)

  const { root: { $router } = {} } = context

  const router = useRouter($router)

  const tableRef = ref(null)
  const selected = useBootstrapTableSelected(tableRef, items)
  const {
    selectedItems
  } = selected

  const onBulkExport = () => {
    const filename = `${$router.currentRoute.path.slice(1).replace('/', '-')}-${(new Date()).toISOString()}.csv`
    const csv = useTableColumnsItems(visibleColumns.value, selectedItems.value)
    useDownload(filename, csv, 'text/csv')
  }

  return {
    useSearch,
    tableRef,
    onBulkExport,
    ...router,
    ...selected,
    ...toRefs(search)
  }
}

// @vue/component
export default {
  name: 'the-search',
  inheritAttrs: false,
  components,
  setup
}
</script>

<!--
<template>
  <b-card ref="container" no-body>
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Search RADIUS Audit Logs'"></h4>
    </b-card-header>
    <pf-search class="flex-shrink-0"
      :quick-with-fields="false"
      :quick-placeholder="$t('Search by MAC or username')"
      save-search-namespace="radiuslogs"
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
          <b-dropdown size="sm" variant="link" :boundary="$refs.container" no-caret>
            <template #button-content>
              <icon name="columns" v-b-tooltip.hover.right :title="$t('Visible Columns')"></icon>
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
              <base-button-export-csv filename="radiuslogs.csv" :disabled="isLoading"
                :columns="columns" :data="items"
              />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
    </div>
    <div class="card-body pt-0" v-scroll-100>
      <b-table class="table-clickable" :items="items" :fields="visibleColumns" :sort-by="sortBy" :sort-desc="sortDesc"
        @sort-changed="onSortingChanged" @row-clicked="onRowClick"
        show-empty hover no-local-sorting sort-icon-left striped>
        <template #empty>
          <pf-empty-table :is-loading="isLoading">{{ $t('No logs found') }}</pf-empty-table>
        </template>
        <template #cell(auth_status)="log">
          <b-badge pill :variant="(['Accept', 'CoA-ACK', 'Disconnect-ACK'].includes(log.item.auth_status)) ? 'success' : 'danger'" class="ml-1">{{ log.item.auth_status }}</b-badge>
        </template>
        <template #cell(node_status)="{ value }">
          <b-badge pill variant="success" v-if="value === 'reg'">{{ $t('Registered') }}</b-badge>
          <b-badge pill variant="warning" v-else-if="value === 'pending'">{{ $t('Pending') }}</b-badge>
          <b-badge pill variant="light" v-else>{{ $t('Unregistered') }}</b-badge>
        </template>
        <template #cell(mac)="{ value }">
          <router-link :to="{ path: `/node/${value}` }"><mac v-text="value"></mac></router-link>
        </template>
        <template #cell(is_phone)="{ value }">
          <icon v-if="parseInt(value) > 0" name="check"></icon>
        </template>
      </b-table>
    </div>
  </b-card>
</template>

<script>
import {
  BaseButtonExportCsv
} from '@/components/new/'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import pfMixinSearchable from '@/components/pfMixinSearchable'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfSearch from '@/components/pfSearch'
import pfFormToggle from '@/components/pfFormToggle'
import scroll100 from '@/directives/scroll-100'

export default {
  name: 'radius-logs-search',
  mixins: [
    pfMixinSearchable
  ],
  components: {
    BaseButtonExportCsv,
    pfEmptyTable,
    pfSearch,
    pfFormToggle
  },
  directives: {
    scroll100
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
          text: 'Auth Status', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'auth_type',
          text: 'Auth Type', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'radius_ip',
          text: 'Server IP', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'auto_reg',
          text: 'Auto Registration', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'called_station_id',
          text: 'Called Station ID', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'calling_station_id',
          text: 'Calling Station ID', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'computer_name',
          text: 'Computer name', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'profile',
          text: 'Connection Profile', // i18n defer
          types: [conditionType.CONNECTION_PROFILE]
        },
        {
          value: 'connection_type',
          text: 'Connection Type', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'created_at',
          text: 'Created', // i18n defer
          types: [conditionType.DATETIME]
        },
        {
          value: 'pf_domain',
          text: 'Domain', // i18n defer
          types: [conditionType.DOMAIN]
        },
        {
          value: 'eap_type',
          text: 'EAP Type', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'event_type',
          text: 'Event Type', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'ifindex',
          text: 'IfIndex', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'ip',
          text: 'IP Address', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'is_phone',
          text: 'Is a Phone', // i18n defer
          types: [conditionType.YESNO]
        },
        {
          value: 'mac',
          text: 'MAC Address', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'nas_identifier',
          text: 'NAS identifier', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'nas_ip_address',
          text: 'NAS IP Address', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'nas_port',
          text: 'NAS Port', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'nas_port_id',
          text: 'NAS Port ID', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'nas_port_type',
          text: 'NAS Port Type', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'node_status',
          text: 'Node Status', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'pf_domain',
          text: 'Domain', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'profile',
          text: 'Profile', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'radius_reply',
          text: 'RADIUS Reply', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'radius_request',
          text: 'RADIUS Request', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'radius_source_ip_address',
          text: 'RADIUS Source IP Address', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'realm',
          text: 'Realm', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'reason',
          text: 'Reason', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'request_time',
          text: 'Request Time', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'role',
          text: 'Role', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'source',
          text: 'Source', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'ssid',
          text: 'Wi-Fi Network SSID', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'stripped_user_name',
          text: 'Stripped User Name', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'switch_id',
          text: 'Switch ID', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'switch_ip_address',
          text: 'Switch IP Address', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'switch_mac',
          text: 'Switch MAC', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'user_name',
          text: 'User Name', // i18n defer
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'uuid',
          text: 'Unique ID', // i18n defer
          types: [conditionType.SUBSTRING]
        }
      ],
      columns: [
        {
          key: 'created_at',
          label: 'Created At', // i18n defer
          sortable: true,
          visible: true,
          class: 'text-nowrap',
          formatter: formatter.datetimeIgnoreZero
        },
        {
          key: 'id',
          label: 'ID', // i18n defer
          required: true,
          sortable: true,
          visible: true
        },
        {
          key: 'auth_status',
          label: 'Auth Status', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'radius_ip',
          label: 'Server IP', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'mac',
          label: 'MAC Address', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'auth_type',
          label: 'Auth Type', // i18n defer
          sortable: true
        },
        {
          key: 'auto_reg',
          label: 'Auto Reg', // i18n defer
          sortable: true
        },
        {
          key: 'calling_station_id',
          label: 'Calling Station ID', // i18n defer
          sortable: true
        },
        {
          key: 'computer_name',
          label: 'Computer Name', // i18n defer
          sortable: true
        },
        {
          key: 'eap_type',
          label: 'EAP Type', // i18n defer
          sortable: true
        },
        {
          key: 'event_type',
          label: 'Event Type', // i18n defer
          sortable: true
        },
        {
          key: 'ip',
          label: 'IP Address', // i18n defer
          sortable: true
        },
        {
          key: 'is_phone',
          label: 'Is a Phone', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'node_status',
          label: 'Node Status', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'pf_domain',
          label: 'Domain', // i18n defer
          sortable: true
        },
        {
          key: 'profile',
          label: 'Profile', // i18n defer
          sortable: true
        },
        {
          key: 'realm',
          label: 'Realm', // i18n defer
          sortable: true
        },
        {
          key: 'reason',
          label: 'Reason', // i18n defer
          sortable: true
        },
        {
          key: 'role',
          label: 'Role', // i18n defer
          sortable: true
        },
        {
          key: 'source',
          label: 'Source', // i18n defer
          sortable: true
        },
        {
          key: 'stripped_user_name',
          label: 'Stripped User Name', // i18n defer
          sortable: true
        },
        {
          key: 'user_name',
          label: 'User Name', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'uuid',
          label: 'Unique ID', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'switch_id',
          label: 'Switch', // i18n defer
          sortable: true
        },
        {
          key: 'switch_mac',
          label: 'Switch MAC', // i18n defer
          sortable: true
        },
        {
          key: 'switch_ip_address',
          label: 'Switch IP Address', // i18n defer
          sortable: true
        },
        {
          key: 'called_station_id',
          label: 'Called Station ID', // i18n defer
          sortable: true
        },
        {
          key: 'connection_type',
          label: 'Connection Type', // i18n defer
          sortable: true
        },
        {
          key: 'ifindex',
          label: 'IfIndex', // i18n defer
          sortable: true
        },
        {
          key: 'nas_identifier',
          label: 'NAS ID', // i18n defer
          sortable: true
        },
        {
          key: 'nas_ip_address',
          label: 'NAS IP Address', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'nas_port',
          label: 'NAS Port', // i18n defer
          sortable: true
        },
        {
          key: 'nas_port_id',
          label: 'NAS Port ID', // i18n defer
          sortable: true
        },
        {
          key: 'nas_port_type',
          label: 'NAS Port Type', // i18n defer
          sortable: true,
          visible: true
        },
        {
          key: 'radius_source_ip_address',
          label: 'RADIUS Source IP Address', // i18n defer
          sortable: true
        },
        {
          key: 'ssid',
          label: 'SSID', // i18n defer
          sortable: true
        },
        {
          key: 'request_time',
          label: 'Request Time', // i18n defer
          sortable: true
        },
        {
          key: 'radius_request',
          label: 'RADIUS Request', // i18n defer
          sortable: true
        },
        {
          key: 'radius_reply',
          label: 'RADIUS Reply', // i18n defer
          sortable: true
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
    onRowClick (item) {
      this.$router.push({ name: 'radiuslog', params: { id: item.id } })
    }
  }
}
</script>
-->