<template>
  <b-card no-body>
    <b-card-header>
      <h4>{{ $t('Maintenance Tasks') }}</h4>
      <p class="mb-0" v-t="'Enabling or disabling a task as well as modifying its interval requires a restart of pfcron to be fully effective.'"></p>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch">
        <base-button-service service="pfcron" restart start stop
          :disabled="isLoading" class="mr-1" />
      </base-search>
      <b-table ref="tableRef"
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
          <span @click.stop="onItemSelected(index)" style="padding: 12px;">
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
            :item="item" @input="item.status = $event" />
        </template>
        <template #cell(interval)="{ item: { interval } }">
          <template v-if="interval">
            <!-- TODO: Temporary workaround for issue #4902 -->
            {{ interval.interval }}{{ interval.unit }}
          </template>
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
  BaseButtonHelp,
  BaseButtonService,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty
} from '@/components/new/'
import ToggleStatus from './ToggleStatus'

const components = {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseButtonService,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty,
  ToggleStatus
}

import { ref, toRefs } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import { useSearch, useRouter } from '../_composables/useCollection'

const setup = (props, context) => {

  const { root: { $router } = {} } = context

  const search = useSearch()
  const {
    items,
    visibleColumns
  } = toRefs(search)

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
    ...router,
    ...selected,
    ...toRefs(search),
    onBulkExport
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
