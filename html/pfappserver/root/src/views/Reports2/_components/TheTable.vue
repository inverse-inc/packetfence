<template>
  <b-container class="px-0" fluid>

    <b-row align-h="end" v-if="!hasQuery">
      <b-col cols="auto" class="mr-auto mb-3">
        <slot />
      </b-col>
      <b-col cols="auto" class="mb-3 align-self-end d-flex">
        <base-search-input-limit v-if="hasLimit"
          :value="limit" @input="setLimit"
          size="md"
          :limits="limits"
          :disabled="isLoading"
        />
        <base-search-input-page v-if="hasCursor"
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
      <template #cell()="{ field, value }">
        <router-link v-if="field.key in columnsIs && columnsIs[field.key].is_node"
          :to="{ path: `/node/${value}` }"><mac v-text="value" /></router-link>
        <router-link v-else-if="field.key in columnsIs && columnsIs[field.key].is_person"
          :to="{ path: `/user/${value}` }">{{ value }}</router-link>
        <template v-else>{{ value }}</template>
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
  BaseSearchInputLimit,
  BaseSearchInputPage,
  BaseTableEmpty
} from '@/components/new/'
const components = {
  BaseSearchInputColumns,
  BaseSearchInputLimit,
  BaseSearchInputPage,
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

import { computed, ref, toRefs } from '@vue/composition-api'
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

  const { columns = [], query_fields = [] } = meta.value

  const hasCursor = computed(() => {
    const { has_cursor } = meta.value
    return has_cursor
  })

  const hasQuery = computed(() => {
    const { query_fields = [] } = meta.value
    return !!query_fields.length
  })

  const hasLimit = computed(() => {
    const { has_limit } = meta.value
    return has_limit
  })

  if (query_fields.length === 0) {
    // no search available
    //  use empty search for default criteria
    search.defaultCondition = () => undefined
    // trigger search
    search.reSearch()
  }

  const columnsIs = computed(() => {
    return columns.reduce((assoc, column) => {
      const { name, is_node, is_person } = column
      return { ...assoc, [name]: { is_node, is_person }}
    }, {})
  })

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
    hasCursor,
    hasQuery,
    hasLimit,
    tableRef,
    columnsIs,
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