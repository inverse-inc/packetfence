<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-flex align-items-center mb-0">
        {{ $t('Search Nodes') }}
      </h4>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch" />
      <b-table ref="tableRef"
        :busy="isLoading"
        :hover="items.length > 0"
        :items="items"
        :fields="visibleColumns"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        @sort-changed="setSort"
        @row-clicked="goToItem"
        class="mb-0 table-no-overflow"
        show-empty
        no-local-sorting
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
            :selectedItems="selectedItems" :visibleColumns="visibleColumns" @bulk="reSearch" class="my-3" />
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
        <template #cell(status)="item">
          <span v-b-tooltip.left.d300 :title="$t('registered')" v-if="item.value === 'reg'">
            <icon name="check-circle" />
          </span>
          <span v-b-tooltip.left.d300 :title="$t('unregistered')" v-else-if="item.value === 'unreg'">
            <icon name="regular/times-circle" />
          </span>
          <span v-b-tooltip.left.d300 :title="$t('pending')" v-else>
            <icon name="regular/dot-circle" />
          </span>
        </template>
        <template #cell(online)="item">
          <span v-b-tooltip.right.d300 :title="$t('on')" v-if="item.value === 'on'">
            <icon name="circle" class="text-success" />
          </span>
          <span v-b-tooltip.right.d300 :title="$t('off')" v-else-if="item.value === 'off'">
            <icon name="circle" class="text-danger" />
          </span>
          <span v-b-tooltip.right.d300 :title="$t('unknown')" v-else>
            <icon name="question-circle" class="text-warning" />
          </span>
        </template>
        <template #cell(mac)="item">
          <mac v-text="item.value" />
        </template>
        <template #cell(pid)="item">
          <b-button variant="link" :to="{ name: 'user', params: { pid: item.value } }">{{ item.value }}</b-button>
        </template>
        <template #cell(device_score)="item">
          <icon-score :score="item.value" />
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
              :confirm="$t('Delete Node?')"
              @click="onRemove(item.mac)"
            >{{ $t('Delete') }}</base-button-confirm>
          </span>
        </template>
      </b-table>
      <b-container fluid v-if="selected.length"
        class="p-0">
        <base-button-bulk-actions
          :selectedItems="selectedItems" :visibleColumns="visibleColumns" @bulk="reSearch" class="my-3" />
      </b-container>
    </div>
  </b-card>
</template>

<script>
import BaseButtonBulkActions from './BaseButtonBulkActions'
import {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty
} from '@/components/new/'
import IconScore from '@/components/IconScore'

const components = {
  BaseButtonBulkActions,
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty,
  IconScore
}

import { ref, toRefs } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useSearch, useStore, useRouter } from '../_composables/useCollection'

const setup = (props, context) => {

  const search = useSearch()
  const {
    reSearch
  } = search
  const {
    items
  } = toRefs(search)

  const { root: { $router, $store } = {} } = context

  const {
    deleteItem
  } = useStore($store)

  const router = useRouter($router)

  const tableRef = ref(null)
  const selected = useBootstrapTableSelected(tableRef, items, 'mac')

  const onRemove = id => {
    deleteItem({ id })
      .then(() => reSearch())
  }

  return {
    useSearch,
    tableRef,
    ...router,
    ...selected,
    ...toRefs(search),
    onRemove
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
