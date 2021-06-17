<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-flex align-items-center">
        {{ $t('Devices') }}
      </h4>
      <b-button-group v-if="!parentId" class="mt-3">
        <b-button v-t="'All'" :variant="(scope === 'all') ? 'primary' : 'outline-secondary'"
          :to="{ name: 'fingerbankDevicesByScope', params: { scope: 'all' } }"></b-button>
        <b-button v-t="'Local'" :variant="(scope === 'local') ? 'primary' : 'outline-secondary'"
          :to="{ name: 'fingerbankDevicesByScope', params: { scope: 'local' } }"></b-button>
        <b-button v-t="'Upstream'" :variant="(scope === 'upstream') ? 'primary' : 'outline-secondary'"
          :to="{ name: 'fingerbankDevicesByScope', params: { scope: 'upstream' } }"></b-button>
      </b-button-group>
    </b-card-header>
    <div class="card-body">
      <base-search v-if="!parentId"
        :use-search="useSearch"
      >
        <b-button variant="outline-primary" @click="onNewClicked">{{ $t('New Device') }}</b-button>
      </base-search>
      <template v-else>
        <bread-crumb :key="parentId" :id="parentId" :scope="scope"
          class="mb-3" />
      </template>
      <b-table ref="tableRef"
        :busy="isLoading"
        :hover="items.length > 0"
        :items="items"
        :fields="visibleColumns"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        @sort-changed="setSort"
        @row-clicked="onRowClicked"
        class="mb-0"
        show-empty
        no-local-sorting
        sort-icon-left
        fixed
        striped
        selectable
        @row-selected="onRowSelected"
      >
        <template v-slot:empty>
          <slot name="emptySearch" v-bind="{ isLoading }">
              <pf-empty-table :is-loading="isLoading">{{ $t('No results found') }}</pf-empty-table>
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
          <span @click.stop="onItemSelected(index)" style="padding: 12px;">
            <template v-if="rowSelected">
              <icon name="check-square" class="bg-white text-success" scale="1.125" />
            </template>
            <template v-else>
              <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
            </template>
          </span>
        </template>
        <template #cell(id)="{ item }">
          <b-button size="sm" variant="outline-primary" class="mr-1" :to="{ name: 'fingerbankDevicesByParentId', params: { parentId: item.id } }">
            <span class="text-nowrap align-items-center ml-2">
              {{ item.id }} <icon name="plus-circle" class="ml-2"></icon>
            </span>
          </b-button>
        </template>
        <template #cell(approved)="{ item }">
          <icon name="circle" :class="{
            'text-success': +item.approved === 1,
            'text-danger': +item.approved === 0
          }" />
        </template>
        <template #head(buttons)>
          <base-search-input-columns
            :disabled="isLoading"
            :value="columns"
            @input="setColumns"
          />
        </template>
        <template #cell(buttons)="{ item }">
          <span class="float-right text-nowrap text-right">
            <base-button-confirm v-if="!item.not_deletable"
              size="sm" variant="outline-danger" class="my-1 mr-1" reverse
              :disabled="isLoading"
              :confirm="$t('Delete Device?')"
              @click="onRemove(item.id)"
            >{{ $t('Delete') }}</base-button-confirm>
            <b-button
              size="sm" variant="outline-primary" class="mr-1"
              @click.stop.prevent="onCloneClicked(item)"
            >{{ $t('Clone') }}</b-button>
          </span>
        </template>
      </b-table>
      <b-container fluid v-if="selected.length"
        class="mt-3 p-0">
        <b-dropdown variant="outline-primary" toggle-class="text-decoration-none">
          <template #button-content>
            {{ $t('{num} selected', { num: selected.length }) }}
          </template>
          <b-dropdown-item @click="onBulkExport">Export to CSV</b-dropdown-item>
        </b-dropdown>
      </b-container>
    </div>
  </b-card>
</template>
<script>
import {
  BaseButtonConfirm,
  BaseSearch,
  BaseSearchInputColumns
} from '@/components/new/'
import BreadCrumb from './BreadCrumb'
import pfEmptyTable from '@/components/pfEmptyTable'

const components = {
  BaseButtonConfirm,
  BaseSearch,
  BaseSearchInputColumns,
  BreadCrumb,
  pfEmptyTable
}

const props = {
  parentId: {
    type: String
  },
  scope: {
    type: String
  }
}

import { ref, toRefs, watch } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import { useSearch, useStore, useRouter } from '../_composables/useCollection'

const setup = (props, context) => {

  const {
    parentId,
    scope
  } = toRefs(props)

  const { root: { $router, $store } = {} } = context

  const {
    deleteItem
  } = useStore($store)

  const router = useRouter($router)
  const {
    goToClone,
    goToItem,
    goToNew
  } = router

  const search = useSearch()
  const {
    reSearch
  } = search
  const {
    items,
    visibleColumns
  } = toRefs(search)

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

  const onRemove = id => {
    deleteItem({ id })
      .then(() => reSearch())
  }

  const onCloneClicked = item => goToClone({ scope: 'local', id: item.id })
  const onNewClicked = () => goToNew({ scope: scope.value })
  const onRowClicked = item => goToItem({ scope: 'local', id: item.id })

  watch([parentId, scope], () => {
    search.requestInterceptor = request => {
      request.scope = scope.value
      if (parentId.value) {
        // rewrite current request
        request.query = { op: 'and', values: [
          { op: 'or', values: [
            { field: 'parent_id', op: 'equals', value: parentId.value }
          ] }
        ] }
      }
      return request
    }
    reSearch()
  }, { immediate: true })

  return {
    useSearch,
    tableRef,
    onRemove,
    onBulkExport,
    onCloneClicked,
    onNewClicked,
    onRowClicked,
    ...router,
    ...selected,
    ...toRefs(search)
  }
}

// @vue/component
export default {
  name: 'the-search',
  inheritAttrs: false,
  props,
  components,
  setup
}
</script>
