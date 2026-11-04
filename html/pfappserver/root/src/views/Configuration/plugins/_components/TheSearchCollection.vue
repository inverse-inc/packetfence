<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ title }}</h4>
      <p v-if="description" class="mt-1 mb-0 text-muted">{{ description }}</p>
    </b-card-header>
    <div class="card-body" v-if="!isAvailable">
      <base-container-loading
        :title="$i18n.t('Plugin unavailable')"
        :text="unavailableText"
        icon="exclamation-triangle"
      />
    </div>
    <div class="card-body" v-else>
      <base-search :use-search="useSearch">
        <b-button variant="outline-primary" @click="goToNew">{{ $t('New {title}', { title: itemTitle }) }}</b-button>
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
          <base-table-empty :is-loading="isLoading">{{ $t('No results found') }}</base-table-empty>
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
        <template v-for="column in badgeColumns" v-slot:[`cell(${column.key})`]="{ item }">
          <span :key="column.key">
            <b-badge v-for="(value, index) in [].concat(cellValue(item, column)).filter(v => v !== undefined && v !== '')" :key="index"
              class="mr-1" :variant="badgeVariant(column, value)">{{ value }}</b-badge>
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
              :confirm="$t('Delete {title}?', { title: itemTitle })"
              @click="onRemove(item.id)"
            >{{ $t('Delete') }}</base-button-confirm>
            <b-button
              size="sm" variant="outline-primary" class="mr-1"
              :disabled="isLoading"
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
  BaseContainerLoading,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty
} from '@/components/new/'

const components = {
  BaseButtonConfirm,
  BaseContainerLoading,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty
}

import { computed, ref, toRefs, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import { useCollectionApi } from '../_api'
import { useItemProps as props, useManifest, useSearch as _useSearch } from '../_composables/useCollection'
import { useRouter } from '../_router'
import { getPlugin } from '../_store'

const setup = (props, context) => {

  const {
    plugin,
    collection
  } = toRefs(props)

  const { root: { $router } = {} } = context

  const manifest = useManifest(props)
  const pluginInfo = computed(() => getPlugin(plugin.value) || {})
  const isAvailable = computed(() => !!pluginInfo.value.available && !!manifest.value.id)
  const unavailableText = computed(() => pluginInfo.value.error || i18n.t('The plugin {plugin} does not answer or does not provide this section.', { plugin: plugin.value }))
  const title = computed(() => manifest.value.title || collection.value)
  const itemTitle = computed(() => manifest.value.item_title || title.value)
  const description = computed(() => manifest.value.description)

  // the search store depends on the plugin collection
  const useSearch = _useSearch(plugin.value, collection.value)
  const search = useSearch()
  const {
    reSearch
  } = search
  const {
    items,
    visibleColumns
  } = toRefs(search)

  // status of the items, merged in the column named by the manifest
  const statuses = ref({})
  const refreshStatus = () => {
    const { status: { endpoint, field = 'status' } = {} } = manifest.value
    if (!endpoint || !isAvailable.value)
      return
    useCollectionApi(plugin.value, manifest.value).status().then(response => {
      const { items: statusItems = [] } = response || {}
      statuses.value = statusItems.reduce((map, statusItem) => ({ ...map, [statusItem.id]: statusItem[field] }), {})
    }).catch(() => {})
  }
  watch(items, refreshStatus, { immediate: true })

  const badgeColumns = computed(() => (manifest.value.columns || []).filter(column => ['badge', 'status'].includes(column.type)))
  const cellValue = (item, column) => (column.type === 'status') ? statuses.value[item.id] : item[column.key]
  const badgeVariant = (column, value) => {
    const { variants = {} } = column
    return variants[value] || 'secondary'
  }

  const { goToNew, goToItem, goToClone } = useRouter($router, plugin.value, collection.value)

  const tableRef = ref(null)
  const selected = useBootstrapTableSelected(tableRef, items)
  const {
    selectedItems
  } = selected

  const onBulkExport = () => {
    const filename = `${$router.currentRoute.path.slice(1).replace(/\//g, '-')}-${(new Date()).toISOString()}.csv`
    const csv = useTableColumnsItems(visibleColumns.value, selectedItems.value)
    useDownload(filename, csv, 'text/csv')
  }

  const onRemove = id => {
    useCollectionApi(plugin.value, manifest.value).delete(id)
      .then(() => reSearch())
  }

  return {
    useSearch,
    tableRef,
    title,
    itemTitle,
    description,
    isAvailable,
    unavailableText,
    badgeColumns,
    cellValue,
    badgeVariant,
    onBulkExport,
    onRemove,
    goToNew,
    goToItem,
    goToClone,
    ...selected,
    ...toRefs(search)
  }
}

// @vue/component
export default {
  name: 'the-search-collection',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
