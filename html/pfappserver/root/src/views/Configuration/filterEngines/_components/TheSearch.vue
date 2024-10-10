<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">
        {{ collection.name }}
      </h4>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch">
        <b-dropdown v-if="types.length"
          :text="$t('New Filter')" variant="outline-primary">
          <b-dropdown-item v-for="type in types" :key="type.value"
            :to="{ name: 'newFilterEngineSubType', params: { collection: collection.collection, type: type.value } }"
          >{{ type.text }}</b-dropdown-item>
        </b-dropdown>
        <b-button v-else
          variant="outline-primary" @click="goToNew({ collection: collection.collection })">{{ $t('New Filter') }}</b-button>
      </base-search>
      <base-table-sortable ref="tableRef"
        :busy="isLoading"
        :hover="items.length > 0"
        :items="items"
        :fields="visibleColumns"
        class="mb-0"
        show-empty
        fixed
        striped
        selectable
        @row-clicked="goToItem"
        @row-selected="onRowSelected"
        @items-sorted="onSorted"
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
        <template #cell(status)="{ item }">
          <toggle-status :value="item.status" :disabled="isLoading"
            :item="item" :collection="collection" @input="item.status = $event" />
        </template>
        <template #cell(scopes)="{ item }">
          <b-badge v-for="(scope, index) in item.scopes" :key="index" class="mr-1" variant="secondary">{{ scope }}</b-badge>
        </template>
        <template #cell(buttons)="{ item }">
          <span class="float-right text-nowrap text-right"
            @click.stop.prevent
          >
            <base-button-confirm v-if="!item.not_deletable"
              size="sm" variant="outline-danger" class="my-1 mr-1" reverse
              :disabled="isLoading"
              :confirm="$t('Delete Filter?')"
              @click="onRemove(item.id)"
            >{{ $t('Delete') }}</base-button-confirm>
            <b-button
              size="sm" variant="outline-primary" class="mr-1"
              @click.stop.prevent="goToClone(item)"
            >{{ $t('Clone') }}</b-button>
          </span>
        </template>
      </base-table-sortable>
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
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty,
  BaseTableSortable
} from '@/components/new/'
import ToggleStatus from './ToggleStatus'

const components = {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty,
  BaseTableSortable,
  ToggleStatus
}

const props = {
  collection: {
    type: Object
  }
}

import { ref, toRefs, watch } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import { apiFactory } from '../_api'
import { useSearch, useStore, useRouter } from '../_composables/useCollection'
import { provisioningTypes } from '../../provisioners/config'

const setup = (props, context) => {

  const {
    collection
  } = toRefs(props)

  const { root: { $store, $router } = {} } = context

  const search = useSearch()
  const {
    reSearch
  } = search
  const {
    items,
    visibleColumns
  } = toRefs(search)

  const router = useRouter($router)
  const {
    goToPreview
  } = router

  watch(() => collection.value.collection, () => {
    search.api = apiFactory(collection.value)
    items.value = []
    reSearch()
  }, { immediate: true })

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

  const {
    deleteItem,
    sortItems,
    getItemOptions
  } = useStore($store)

  const onRemove = id => {
    deleteItem({ ...collection.value, id })
      .then(() => reSearch())
  }

  const onSorted = _items => {
    items.value = _items
    sortItems({ ...collection.value, items: items.value.map(item => item.id) })
      .then(() => reSearch())
  }


  const types = ref([])
  getItemOptions(collection.value)
    .then(filterEngineOptions => {
      const { meta: { type: { allowed: filterEngineTypes = [] } = {} } = {} } = filterEngineOptions
      types.value = filterEngineTypes
        // friendly names
        .map(({ value }) => {
          return { text: provisioningTypes[value] || value, value }
        })
        // sorted by locale
        .sort((a,b) => a.text.localeCompare(b.text))
    })

  return {
    useSearch,
    tableRef,
    ...router,
    ...selected,
    ...toRefs(search),
    goToPreview,
    onBulkExport,
    onRemove,
    onSorted,
    types,
  }
}

// @vue/component
export default {
  name: 'the-search',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
