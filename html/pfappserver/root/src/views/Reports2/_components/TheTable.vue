<template>
  <b-container class="mx-0" fluid>
    <b-table ref="tableRef"
      :busy="isLoading"
      :hover="items.length > 0"
      :items="items"
      :fields="visibleColumns"
      class="mb-0"
      show-empty
      no-local-sorting
      fixed
      striped
      selectable
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
  </b-container>
</template>
<script>
import {
  BaseSearchInputColumns,
  BaseTableEmpty
} from '@/components/new/'
const components = {
  BaseSearchInputColumns,
  BaseTableEmpty
}

const props = {
  report: {
    type: Object
  },
  meta: {
    type: Object
  }
}

import { ref, toRefs } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import { useSearchFactory } from '../_search'

const setup = (props, context) => {

  const {
    report,
    meta
  } = toRefs(props)

  const { root: { $router } = {} } = context

  const useSearch = useSearchFactory(report, meta)
  const search = useSearch()

  const {
    items,
    visibleColumns
  } = toRefs(search)

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

  return {
    tableRef,
    ...selected,
    ...toRefs(search),
    onBulkExport
  }
}
// @vue/component
export default {
  name: 'the-table',
  components,
  props,
  setup
}
</script>