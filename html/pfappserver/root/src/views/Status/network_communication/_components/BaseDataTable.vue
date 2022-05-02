<template>
  <b-card no-body>
    <b-card-header>
      Data
    </b-card-header>
    <b-table ref="tableRef"
      :busy="isLoading"
      :hover="data.length > 0"
      :items="data"
      :fields="visibleColumns"
      :sort-by="sortBy"
      :sort-desc="sortDesc"
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

const components = {
  BaseButtonBulkActions,
  BaseSearchInputColumns,
  BaseTableEmpty,
}

const props = {
  data: {
    type: Array
  }
}

import { computed, ref, toRefs } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import i18n from '@/utils/locale'
import { useSearchData } from '../_composables/useCollection'

const setup = (props) => {

  const {
    data
  } = toRefs(props)

  const search = useSearchData()

  const tableRef = ref(null)
  const selected = useBootstrapTableSelected(tableRef, data, 'timestamp')

  return {
    tableRef,
    ...selected,
    ...toRefs(search),
  }
}

// @vue/component
export default {
  name: 'base-data-table',
  components,
  props,
  setup
}
</script>