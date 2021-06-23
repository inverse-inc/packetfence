<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-flex align-items-center">
        {{ $t('DHCPv6 Enterprises') }}
      </h4>
      <b-button-group class="mt-3">
        <b-button v-t="'All'" :variant="(scope === 'all') ? 'primary' : 'outline-secondary'"
          :to="{ name: 'fingerbankDhcpv6EnterprisesByScope', params: { scope: 'all' } }"></b-button>
        <b-button v-t="'Local'" :variant="(scope === 'local') ? 'primary' : 'outline-secondary'"
          :to="{ name: 'fingerbankDhcpv6EnterprisesByScope', params: { scope: 'local' } }"></b-button>
        <b-button v-t="'Upstream'" :variant="(scope === 'upstream') ? 'primary' : 'outline-secondary'"
          :to="{ name: 'fingerbankDhcpv6EnterprisesByScope', params: { scope: 'upstream' } }"></b-button>
      </b-button-group>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch">
        <b-button variant="outline-primary" @click="onNewClicked">{{ $t('New DHCPv6 Enterprise') }}</b-button>
      </base-search>
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
        <template #cell(buttons)="{ item }">
          <span class="float-right text-nowrap text-right">
            <base-button-confirm v-if="!item.not_deletable"
              size="sm" variant="outline-danger" class="my-1 mr-1" reverse
              :disabled="isLoading"
              :confirm="$t('Delete DHCPv6 Enterprise?')"
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
          <b-dropdown-item @click="onBulkExport">{{ $t('Export to CSV') }}</b-dropdown-item>
        </b-dropdown>
      </b-container>
    </div>
  </b-card>
</template>
<script>
import {
  BaseButtonConfirm,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty
} from '@/components/new/'

const components = {
  BaseButtonConfirm,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty
}

const props = {
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

  watch(scope, () => {
    search.requestInterceptor = request => {
      request.scope = scope.value
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
