<template>
  <b-card no-body>
    <b-card-header>
      <b-row align-v="center">
        <b-col cols="auto">
          <h5 class="mb-0 d-inline">{{ $i18n.t('Data') }}</h5>
        </b-col>
        <b-col cols="auto" class="d-flex ml-auto">
          <b-form-select v-model="perPage"
            :options="[10, 25, 50, 100, 250, 500, 1000].map(value => ({ text: value, value }))"
            :disabled="isLoading"
            class="mr-3"
          />
          <b-pagination v-model="currentPage"
            :disabled="isLoading"
            :total-rows="items.length"
            class="mb-0" />
        </b-col>
      </b-row>
    </b-card-header>
    <b-table ref="tableRef"
      :busy="isLoading"
      :hover="items.length > 0"
      :items="items"
      :fields="visibleColumns"
      :sort-by="sortBy"
      :sort-desc="sortDesc"
      :per-page="perPage"
      :current-page="currentPage"
      @sort-changed="setSort"
      class="mb-0"
      show-empty
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
      <template #top-row v-if="selected.length">
        <base-button-bulk-actions
          :selectedItems="selectedItems" :visibleColumns="visibleColumns" class="m-3" />
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
      <template #cell(mac)="{ value }">
        <node-dropdown :id="value" variant="link" class="px-0" toggle-class="p-0" dropup />
      </template>
      <template #cell(buttons)>
        <span class="float-right text-nowrap text-right mr-3">
          <b-button variant="outline-primary">Action</b-button>
        </span>
      </template>
    </b-table>
      <b-container fluid v-if="selected.length"
        class="p-0">
        <base-button-bulk-actions
          :selectedItems="selectedItems" :visibleColumns="visibleColumns" class="m-3" />
      </b-container>
  </b-card>
</template>
<script>
import BaseButtonBulkActions from './BaseButtonBulkActions'
import {
  BaseSearchInputColumns,
  BaseTableEmpty,
} from '@/components/new/'
import NodeDropdown from '@/views/Nodes/_components/BaseButtonDropdown'

const components = {
  BaseButtonBulkActions,
  BaseSearchInputColumns,
  BaseTableEmpty,
  NodeDropdown,
}

import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useSearch } from '../_composables/useCollection'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const search = useSearch()
  const tableRef = ref(null)

  const isLoading = computed(() => $store.getters['$_fingerbank_communication/isLoading'])
  const items = computed(() => $store.getters['$_fingerbank_communication/tabular'])
  const selected = useBootstrapTableSelected(tableRef, items, 'id')

  const perPage = ref(100)
  const currentPage = ref(1)

  watch([items, perPage], () => {
    currentPage.value = 1
  })

  return {
    tableRef,
    ...selected,
    ...toRefs(search),

    isLoading,
    items, // overload

    perPage,
    currentPage,
  }
}

// @vue/component
export default {
  name: 'base-data-table',
  components,
  setup
}
</script>