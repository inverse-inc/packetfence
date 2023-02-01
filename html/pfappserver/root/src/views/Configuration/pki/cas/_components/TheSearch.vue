<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ $t('Certificate Authorities') }}</h4>
      <base-services v-bind="services" class="mt-3 mb-0" variant="info" />
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch" :disabled="!isServiceAlive">
        <b-button :disabled="isLoading || !isServiceAlive"
          variant="outline-primary" @click="goToNew">{{ $t('New Certificate Authority') }}</b-button>
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
              @click.stop.prevent="goToClone(useTableColumnsItems)"
            >{{ $t('Clone') }}</b-button>
            <b-button
              size="sm" variant="outline-primary" class="mr-1 text-nowrap"
              :disabled="!isServiceAlive"
              @click.stop.prevent="onClipboard(item)"
            >{{ $t('Copy Certificate') }}</b-button>
            <b-button
              size="sm" variant="outline-primary" class="mr-1 text-nowrap"
              :disabled="!isServiceAlive" :to="{ name: 'newPkiProfile', params: { ca_id: item.id } }"
            >{{ $t('New Template') }}</b-button>
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
  BaseServices,
  BaseTableEmpty
} from '@/components/new/'

const components = {
  BaseButtonConfirm,
  BaseSearch,
  BaseSearchInputColumns,
  BaseServices,
  BaseTableEmpty
}

import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import { useSearch, useRouter, useServices } from '../_composables/useCollection'
import i18n from '@/utils/locale'

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
    if($store.getters['system/isSaas']) {
      const { pfpki: { available = false } = {} } = $store.getters['k8s/services']
      return available
    }
    else {
      return $store.dispatch('cluster/getServiceCluster', 'pfpki').then(() => {
        const { pfpki: { hasAlive = false } = {} } = $store.getters['cluster/servicesByServer']
        return hasAlive
      })
    }
  })
  watch(isServiceAlive, () => {
    if (isServiceAlive.value)
      reSearch()
  })

  const router = useRouter($router)

  const tableRef = ref(null)
  const selected = useBootstrapTableSelected(tableRef, items)
  const {
    selectedItems
  } = selected

  const onClipboard = item => {
    $store.dispatch('$_pkis/getCa', item.id).then(ca => {
      try {
        navigator.clipboard.writeText(ca.cert).then(() => {
          $store.dispatch('notification/info', { message: i18n.t('<code>{cn}</code> certificate copied to clipboard', ca) })
        }).catch(() => {
          $store.dispatch('notification/danger', { message: i18n.t('Could not copy <code>{cn}</code> certificate to clipboard.', ca) })
        })
      } catch (e) {
        $store.dispatch('notification/danger', { message: i18n.t('Clipboard not supported.') })
      }
    })
  }

  const onBulkExport = () => {
    const filename = `${$router.currentRoute.path.slice(1).replace('/', '-')}-${(new Date()).toISOString()}.csv`
    const csv = useTableColumnsItems(visibleColumns.value, selectedItems.value)
    useDownload(filename, csv, 'text/csv')
  }

  const services = useServices()

  return {
    useSearch,
    isServiceAlive,
    tableRef,
    onClipboard,
    onBulkExport,
    ...router,
    ...selected,
    ...toRefs(search),
    services,
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
