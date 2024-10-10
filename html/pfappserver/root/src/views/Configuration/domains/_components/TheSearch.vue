<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-flex align-items-center mb-0">
        {{ $t('Active Directory Domains') }}
        <base-button-help class="text-black-50 ml-1" url="PacketFence_Installation_Guide.html#_microsoft_active_directory_ad" />
      </h4>
      <base-services v-bind="services" class="mt-3 mb-0" variant="info" />
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch">
        <b-button variant="outline-primary" @click="goToNew">{{ $t('New Domain') }}</b-button>
      </base-search>
      <b-table ref="tableRef"
        :busy="isLoading"
        :hover="decoratedItems.length > 0"
        :items="decoratedItems"
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
          <span @click.stop="onItemSelected(index)">
            <template v-if="rowSelected">
              <icon name="check-square" class="bg-white text-success" scale="1.125" />
            </template>
            <template v-else>
              <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
            </template>
          </span>
        </template>
        <template #cell(nt_key_cache_enabled)="{ item }">
          <icon name="circle" :class="{ 'text-success': item.nt_key_cache_enabled === 'enabled', 'text-danger': item.nt_key_cache_enabled !== 'enabled' }"
            v-b-tooltip.hover.left.d300 :title="$t(item.nt_key_cache_enabled)"></icon>
        </template>
        <template #cell(ntlm_cache)="{ item }">
          <icon name="circle" :class="{ 'text-success': item.ntlm_cache === 'enabled', 'text-danger': item.ntlm_cache !== 'enabled' }"
            v-b-tooltip.hover.left.d300 :title="$t(item.ntlm_cache)"></icon>
        </template>
        <template #cell(domain_joined)="{ item }">
          <icon name="circle" :class="{ 'text-success': item.domain_joined === true, 'text-danger': item.domain_joined === false }"></icon>
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
              :confirm="$t('Delete Domain?')"
              @click="onRemove(item.id)"
            >{{ $t('Delete') }}</base-button-confirm>
            <b-button
              size="sm" variant="outline-primary" class="mr-1"
              @click.stop.prevent="goToClone(item)"
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
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  BaseServices,
  BaseTableEmpty
} from '@/components/new/'

const components = {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  BaseServices,
  BaseTableEmpty
}

const props = {
  autoJoinDomain: { // from DomainView, through router
    type: String,
    default: null
  }
}

import { createDebouncer } from 'promised-debounce'
import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import { useSearch, useStore, useRouter, useServices } from '../_composables/useCollection'

const setup = (props, context) => {

  const { root: { $router, $store } = {} } = context

  const services = useServices()

  const {
    deleteItem,
    getItem,
    testItem
  } = useStore($store)

  const search = useSearch()
  const {
    reSearch
  } = search
  const {
    columns,
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

  const onRemove = id => {
    deleteItem({ id })
      .then(() => reSearch())
  }

  let joinDebouncer
  const joinStatuses = ref({})
  const decoratedItems = computed(() => {
    return items.value.map(item => ({ ...item, domain_joined: joinStatuses.value[item.id]  }))
  })
  const showJoined = computed(() => columns.value.filter(column => column.key === 'domain_joined' && column.visible).length > 0)
  watch([items, showJoined], () => {
    if (!joinDebouncer) {
      joinDebouncer = createDebouncer()
    }
    joinDebouncer({ handler: () => {
      if (showJoined.value) {
        items.value.forEach(item => {
          joinStatuses.value = { ...joinStatuses.value, [item.id]: null }
          getItem({ ...item, quiet: true }).then(_item => {
            const { machine_account_password } = _item
            if (machine_account_password) {
              testItem(_item).then(() => {
                joinStatuses.value = { ...joinStatuses.value, [item.id]: true }
              }).catch(() => {
                joinStatuses.value = { ...joinStatuses.value, [item.id]: false }
              })
            }
          }).catch(() => {
            joinStatuses.value = { ...joinStatuses.value, [item.id]: false }
          })
        })
      }
    }, time: 1E3 }) // debounce DOM mutations
  }, { deep: true })

  return {
    useSearch,
    tableRef,
    onRemove,
    onBulkExport,
    ...router,
    ...selected,
    ...toRefs(search),
    services,
    decoratedItems
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
