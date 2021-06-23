<template>
  <div>
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
      @row-clicked="goToItem({ ...$event, tenantId })"
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
          @input="$emit('setColumns', $event)"
        />
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
      <template #cell(radius_auth)="{ item: { radius_auth: value } }">
        <span v-if="value.length === 0">&nbsp;</span>
        <b-badge v-else v-for="(item, index) in value" :key="index" class="ml-2" variant="secondary">{{ item }}</b-badge>
      </template>
      <template #cell(radius_acct)="{ item: { radius_acct: value } }">
        <span v-if="value.length === 0">&nbsp;</span>
        <b-badge v-else v-for="(item, index) in value" :key="index" class="ml-2" variant="secondary">{{ item }}</b-badge>
      </template>
      <template #cell(portal_strip_username)="{ item: { portal_strip_username: value } }">
        <icon name="circle" :class="{ 'text-success': value === 'enabled', 'text-danger': value === 'disabled' }"
          v-b-tooltip.hover.left.d300 :title="$t(value)"></icon>
      </template>
      <template #cell(admin_strip_username)="{ item: { admin_strip_username: value } }">
        <icon name="circle" :class="{ 'text-success': value === 'enabled', 'text-danger': value === 'disabled' }"
          v-b-tooltip.hover.left.d300 :title="$t(value)"></icon>
      </template>
      <template #cell(radius_strip_username)="{ item: { radius_strip_username: value } }">
        <icon name="circle" :class="{ 'text-success': value === 'enabled', 'text-danger': value === 'disabled' }"
          v-b-tooltip.hover.left.d300 :title="$t(value)"></icon>
      </template>
      <template #cell(buttons)="{ item }">
        <span class="float-right text-nowrap text-right"
          @click.stop.prevent
        >
          <base-button-confirm v-if="!item.not_deletable"
            size="sm" variant="outline-danger" class="my-1 mr-1" reverse
            :disabled="isLoading"
            :confirm="$t('Delete Source?')"
            @click="onRemove(item.id)"
          >{{ $t('Delete') }}</base-button-confirm>
          <b-button
            size="sm" variant="outline-primary" class="mr-1"
            @click.stop.prevent="goToClone({ ...item, tenantId })"
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
</template>
<script>
import {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearchInputColumns,
  BaseTableEmpty,
  BaseTableSortable
} from '@/components/new/'

const components = {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearchInputColumns,
  BaseTableEmpty,
  BaseTableSortable
}

const props = {
  isLoading: {
    type: Boolean
  },
  items: {
    type: Array
  },
  columns: {
    type: Array
  },
  visibleColumns: {
    type: Array
  },
  tenantId: {
    type: [Number, String]
  }
}
import { ref, toRefs } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import { useRouter, useStore } from '../_composables/useCollection'

const setup = (props, context) => {

  const {
    items,
    visibleColumns
  } = toRefs(props)

  const { emit, root: { $router, $store } = {} } = context

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

  const {
    deleteItem,
    sortItems
  } = useStore($store)

  const onRemove = id => {
    deleteItem({ id })
      .then(() => emit('reSearch'))
  }

  const onSorted = _items => {
    items.value = _items
    sortItems({ items: items.value.map(item => item.id) })
      .then(() => emit('reSearch'))
  }

  return {
    tableRef,
    ...router,
    ...selected,
    onBulkExport,
    onRemove,
    onSorted
  }

}

// @vue/component
export default {
  name: 'the-table',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>