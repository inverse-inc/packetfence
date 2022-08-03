<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline" v-t="'Network Threats'"></h4>
    </b-card-header>
    <div class="card-body">
      <b-row>
        <b-col cols="6">
          <b-tabs small class="fixed">
            <b-tab class="border-1 border-right border-bottom border-left p-3">
              <template #title>
                {{ $i18n.t('Search') }}
              </template>
              <the-search :selected-security-events="selectedSecurityEvents" />
            </b-tab>
          </b-tabs>
        </b-col>
        <b-col cols="6">
          <b-tabs small class="fixed">
            <b-tab class="border-1 border-right border-bottom border-left">
              <template #title>
                {{ $i18n.t('Security Events') }}
                <b-badge v-if="selectedSecurityEvents.length" pill variant="primary" class="ml-1">{{ selectedSecurityEvents.length }}</b-badge>
                <base-icon-preference id="vizsec::filters"
                  class="ml-1" />
              </template>
              <base-filter-security-events v-model="selectedSecurityEvents" />
            </b-tab>
          </b-tabs>
        </b-col>
      </b-row>
      <b-row align-h="end">
        <b-col cols="auto" class="mr-auto my-3">
          <slot />
        </b-col>
        <b-col cols="auto" class="my-3 align-self-end d-flex">
          <base-search-input-limit
            :value="limit" @input="setLimit"
            size="md"
            :limits="limits"
            :disabled="isLoading"
          />
          <base-search-input-page
            :value="page" @input="setPage"
            class="ml-3"
            :limit="limit"
            :total-rows="totalRows"
            :disabled="isLoading"
          />
        </b-col>
      </b-row>
      <b-table ref="tableRef"
        :busy="isLoading"
        :hover="items.length > 0"
        :items="items"
        :fields="visibleColumns"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        @sort-changed="setSort"
        class="mb-0"
        no-local-sorting
        no-provider-sorting
        selectable
        show-empty
        striped
        @row-selected="onRowSelected"
      >
        <template v-slot:empty>
          <slot name="emptySearch" v-bind="{ isLoading }">
            <base-table-empty :is-loading="isLoading">{{ $t('No results found') }}</base-table-empty>
          </slot>
        </template>
        <template #head(selected)>
          <span @click.stop.prevent="onAllSelected">
            <template v-if="selected.length > 0">
              <icon name="check-square" class="bg-white text-success" scale="1.125" style="max-width: 1.125em;" />
            </template>
            <template v-else>
              <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" style="max-width: 1.125em;" />
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
        <template #cell(status)="{ value }">
          <span v-b-tooltip.right.d300 :title="$t('open')" v-if="value === 'open'">
            <icon name="circle" class="text-danger" />
          </span>
          <span v-b-tooltip.right.d300 :title="$t('closed')" v-else>
            <icon name="circle" class="text-light" />
          </span>
        </template>
        <template #cell(mac)="{ value }">
          <node-dropdown :id="value" variant="link" class="px-0" toggle-class="p-0" dropup />
        </template>
        <template #cell(security_event_id)="{ value }">
          <router-link :to="{ path: `/configuration/security_event/${value}` }">{{ securityEventMap[value] || '...' }}</router-link>
        </template>
        <template #cell(buttons)="{ item }">
          <span class="float-right text-nowrap text-right mr-3">
            <b-button v-if="item.status === 'open'"
              size="sm" variant="outline-danger" @click="onRelease(item.mac, item.id)">{{ $t('Release Event') }}</b-button>
          </span>
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
  BaseIconPreference,
  BaseSearchInputColumns,
  BaseSearchInputLimit,
  BaseSearchInputPage,
  BaseTableEmpty
} from '@/components/new/'
import BaseFilterSecurityEvents from './BaseFilterSecurityEvents'
import TheSearch from './TheSearch'
import NodeDropdown from '@/views/Nodes/_components/BaseButtonDropdown'
const components = {
  BaseFilterSecurityEvents,
  BaseIconPreference,
  BaseSearchInputColumns,
  BaseSearchInputLimit,
  BaseSearchInputPage,
  BaseTableEmpty,
  NodeDropdown,
  TheSearch,
}

import { computed, onMounted, ref, toRefs } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import usePreference from '@/composables/usePreference'
import { useSearch } from '../_search'

const setup = (props, context) => {

  const { root: { $router, $store } = {} } = context

  const search = useSearch()
  const {
    reSearch,
  } = search
  const {
    items,
    visibleColumns
  } = toRefs(search)

  const selectedSecurityEvents = usePreference('vizsec::filters', 'securityEvents', [])

  const totalOpen = computed(() => $store.state.$_network_threats.totalOpen)
  const totalClosed = computed(() => $store.state.$_network_threats.totalClosed)
  const perDeviceClassOpen = computed(() => $store.getters['$_network_threats/perDeviceClassOpen'])
  const perDeviceClassClosed = computed(() => $store.getters['$_network_threats/perDeviceClassClosed'])

  const tableRef = ref(null)
  let selected = useBootstrapTableSelected(tableRef, items, null)

  const onBulkExport = () => {
    const {
      selectedItems
    } = selected
    const filename = `${$router.currentRoute.path.slice(1).replace('/', '-')}-${(new Date()).toISOString()}.csv`
    const csv = useTableColumnsItems(visibleColumns.value, selectedItems.value)
    useDownload(filename, csv, 'text/csv')
  }

  const onRelease = (mac, security_event_id) => {
    $store.dispatch('$_nodes/clearSecurityEventNode', { mac, security_event_id })
      .then(() => {
        $store.dispatch('$_network_threats/stat')
        reSearch()
      })
  }

  const securityEventMap = ref({})
  onMounted(() => {
    $store.dispatch('$_security_events/all').then(items => {
      securityEventMap.value = items.reduce((assoc, item) => {
        return { ...assoc, [item.id]: item.desc }
      }, {})
    })
  })

  return {
    selectedSecurityEvents,

    totalOpen,
    totalClosed,
    perDeviceClassOpen,
    perDeviceClassClosed,

    tableRef,
    ...selected,
    ...toRefs(search),
    onBulkExport,
    onRelease,

    securityEventMap
  }
}

// @vue/component
export default {
  name: 'the-view',
  inheritAttrs: false,
  components,
  setup
}
</script>

<style lang="scss" scoped>
.tabs.fixed {
  div[role="tabpanel"] {
    height: 50vh;
    overflow-y: auto;
    overflow-x: hidden;
    .card {
      border: 0px !important;
      box-shadow: 0px 0px 0px 0px !important;
    }
  }
}
</style>