<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ $t('Templates') }}</h4>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch" :disabled="!isServiceAlive">
        <b-dropdown :text="$t('New Template')" variant="outline-primary" :disabled="!isServiceAlive || cas.length === 0">
          <b-dropdown-header>{{ $t('Choose Certificate Authority') }}</b-dropdown-header>
          <b-dropdown-item v-for="ca in casSorted" :key="ca.ID" :to="{ name: 'newPkiProfile', params: { ca_id: ca.ID } }">{{ ca.cn }}</b-dropdown-item>
        </b-dropdown>
        <base-button-service :disabled="isLoading"
          service="pfpki" restart start stop
          class="ml-1" />
      </base-search>
      <b-table ref="tableRef"
        :busy="isLoading || !isServiceAlive"
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
        no-sort-reset
        sort-icon-left
        fixed
        striped
        selectable
        @row-selected="onRowSelected"
      >
        <template v-slot:empty>
          <slot name="emptySearch" v-bind="{ isLoading }">
            <base-table-empty v-if="isServiceAlive"
              :is-loading="isLoading"
            >{{ $i18n.t('No results found') }}</base-table-empty>
            <base-table-empty v-else
              :is-loading="isLoading"
              :text="$t('Start the pfpki service.')"
            >{{ $i18n.t('Service not running') }}</base-table-empty>
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
            :disabled="!isServiceAlive || isLoading"
            :value="columns"
            @input="setColumns"
          />
        </template>
        <template #cell(buttons)="{ item }">
          <span class="float-right text-nowrap text-right">
            <b-button
              size="sm" variant="outline-primary" class="mr-1"
              :disabled="!isServiceAlive"
              @click.stop.prevent="goToClone({ id: item.ID, ...item })"
            >{{ $t('Clone') }}</b-button>
            <b-button
              size="sm" variant="outline-primary" class="mr-1 text-nowrap"
              :disabled="!isServiceAlive" :to="{ name: 'newPkiCert', params: { profile_id: item.ID } }"
            >{{ $t('New Certificate') }}</b-button>
          </span>
        </template>
        <template #cell(ca_name)="{ item }">
          <router-link :is="(isServiceAlive) ? 'router-link' : 'span'" :to="{ name: 'pkiCa', params: { id: item.ca_id } }">{{ item.ca_name }}</router-link>
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
  BaseButtonService,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty
} from '@/components/new/'

const components = {
  BaseButtonConfirm,
  BaseButtonService,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty
}

import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import { useSearch, useRouter } from '../_composables/useCollection'

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

  const isServiceAlive = computed(() => {
    const { state: { services: { cache: { pfpki: { alive } = {} } = {} } = {} } = {} } = $store
    return alive
  })
  watch(isServiceAlive, () => {
    if (isServiceAlive.value)
      reSearch()
  })

  $store.dispatch('$_pkis/allCas')
  const cas = computed(() => $store.getters['$_pkis/cas'] || [])
  const casSorted = computed(() => {
    return Array.prototype.slice.call(cas.value)
      .sort((a, b) => a.cn.localeCompare(b.cn)) // sort cas by 'cn'
  })

  const router = useRouter($router)

  const tableRef = ref(null)
  const selected = useBootstrapTableSelected(tableRef, items, 'ID')
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
    isServiceAlive,
    cas,
    casSorted,
    tableRef,
    onBulkExport,
    ...router,
    ...selected,
    ...toRefs(search)
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
