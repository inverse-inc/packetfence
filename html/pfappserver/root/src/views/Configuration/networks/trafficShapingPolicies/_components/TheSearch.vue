<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ $t('Inline Traffic Shaping Policy') }}</h4>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch">
        <b-dropdown :text="$t('New Traffic Shaping Policy')"
          :disabled="roles.length === 0"
          variant="outline-primary" class="mr-1">
          <b-dropdown-header class="text-secondary">{{ $t('To Role') }}</b-dropdown-header>
          <b-dropdown-item v-for="(role, index) in roles" :key="index"
            :to="{ name: 'newTrafficShaping', params: { role } }">{{ role }}</b-dropdown-item>
        </b-dropdown>
      </base-search>
      <b-table ref="tableRef"
        :busy="isLoading"
        :hover="items.length > 0"
        :items="items"
        :fields="visibleColumns"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        @sort-changed="setSort"
        @row-clicked="goToItem"
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
          <span @click.stop="onItemSelected(index)" style="padding: 12px;">
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
        <template #cell(group)="{ value }">
          <b-link :to="{ name: 'switch_group', params: { id: value } }">{{ value }}</b-link>
        </template>
        <template #cell(type)="{ item }">
          <template v-if="switchTemplates.includes(item.type)">
            <b-link :to="{ name: 'switchTemplate', params: { id: item.type } }" v-b-tooltip.hover.top.d300 :title="$t('View Switch Template')">{{ item.type }}</b-link>
          </template>
          <template v-else>
            {{ item.type }}
          </template>
        </template>
        <template #cell(buttons)="{ item }">
          <span class="float-right text-nowrap text-right">
            <base-button-confirm v-if="!item.not_deletable"
              size="sm" variant="outline-danger" class="my-1 mr-1" reverse
              :disabled="isLoading"
              :confirm="$t('Delete Traffic Shaping Policy?')"
              @click="onRemove(item.id)"
            >{{ $t('Delete') }}</base-button-confirm>
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

import { ref, toRefs } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import { useSearch, useStore, useRouter } from '../_composables/useCollection'

const setup = (props, context) => {

  const search = useSearch()
  const {
    reSearch
  } = search
  const {
    items,
    visibleColumns
  } = toRefs(search)

  const { root: { $router, $store } = {} } = context

  const {
    deleteItem
  } = useStore($store)

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

  const onRemove = id => {
    deleteItem({ id })
      .then(() => reSearch())
  }

  const roles = ref([])
  $store.dispatch('$_roles/all')
    .then(_roles => {
      const __roles = _roles.map(role => role.id)
      $store.dispatch('$_traffic_shaping_policies/all').then(policies => {
        const _policies = policies.map(policy => policy.id)
        roles.value = __roles.filter(role => !(_policies.includes(role)))
      })
    })

  return {
    useSearch,
    tableRef,
    onBulkExport,
    onRemove,
    ...router,
    ...selected,
    ...toRefs(search),
    roles
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
