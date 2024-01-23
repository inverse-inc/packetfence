<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ $t('Switches') }}</h4>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch">
        <b-dropdown :text="$t('New Switch')"
          variant="outline-primary" class="mr-1">
          <b-dropdown-header class="text-secondary">{{ $t('To Group') }}</b-dropdown-header>
          <b-dropdown-item v-for="(switchGroup, index) in switchGroups" :key="index"
            :to="{ name: 'newSwitch', params: { switchGroup: switchGroup.id } }">{{ switchGroup.id }}</b-dropdown-item>
        </b-dropdown>
        <b-button variant="outline-primary" class="mr-1" :to="{ name: 'importSwitch' }">{{ $t('Import CSV') }}</b-button>
        <b-button variant="outline-primary" class="mr-1" @click="onPrecreateAcls">{{ $t('Precreate ACLs') }}</b-button>
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
        <template #cell(UsePushACLs)="item">
          <span v-b-tooltip.right.d300 :title="$t('yes')" v-if="item.value === 'Y'">
            <icon name="circle" class="text-success" />
          </span>
          <span v-b-tooltip.right.d300 :title="$t('no')" v-else-if="item.value === 'N'">
            <icon name="circle" class="text-danger" />
          </span>
        </template>
        <template #cell(UseDownloadableACLs)="item">
          <span v-b-tooltip.right.d300 :title="$t('yes')" v-if="item.value === 'Y'">
            <icon name="circle" class="text-success" />
          </span>
          <span v-b-tooltip.right.d300 :title="$t('no')" v-else-if="item.value === 'N'">
            <icon name="circle" class="text-danger" />
          </span>
        </template>
        <template #cell(buttons)="{ item }">
          <span class="float-right text-nowrap text-right">
            <base-button-confirm v-if="!item.not_deletable"
              size="sm" variant="outline-danger" class="my-1 mr-1" reverse
              :disabled="isLoading"
              :confirm="$t('Delete Switch?')"
              @click="onRemove(item.id)"
            >{{ $t('Delete') }}</base-button-confirm>
            <b-button
              size="sm" variant="outline-secondary" class="mr-1"
              :disabled="isLoading"
              @click.stop.prevent="onInvalidateCache(item)"
            >{{ $t('Invalidate Cache') }}</b-button>
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

  const {
    deleteItem,
    precreateItemAcls
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

  const onInvalidateCache = item => {
    $store.dispatch('$_switches/invalidateSwitchCache', item.id)
      .then(() => {
        $store.dispatch('notification/info', { message: i18n.t('Switch <code>{id}</code> cache invalidated.', item) })
        reSearch()
      })
      .catch(() => {
        $store.dispatch('notification/danger', { message: i18n.t('Switch <code>{id}</code> cache could not be invalidated.', item) })
      })
    }

  const onRemove = id => {
    deleteItem({ id })
      .then(() => reSearch())
  }

  const switchGroups = ref([])
  $store.dispatch('$_switch_groups/all')
    .then(_switchGroups => {
      switchGroups.value = _switchGroups.sort((a, b) => a.id.localeCompare(b.id))
    })

  const switchTemplates = ref([])
  $store.dispatch('$_switches/optionsBySwitchGroup')
    .then(switchGroupOptions => {
      const { meta: { type: { allowed: switchGroups = [] } = {} } = {} } = switchGroupOptions
      switchGroups.map(switchGroup => {
        const { options: switchGroupMembers } = switchGroup
        switchGroupMembers.map(switchGroupMember => {
            const { is_template, value } = switchGroupMember
            if (is_template) {
              switchTemplates.value.push(value)
            }
        })
      })
    })

  const onPrecreateAcls = () => {
    $store.dispatch('$_switches/allPushACLs').then(ids => {
      ids.forEach(id => {
        precreateItemAcls({ id }).then(() => {
          $store.dispatch('notification/info', { message: i18n.t('Successfully precreated ACLs on switch <code>{id}</code>.', { id }) })
        }).catch(() => {
          $store.dispatch('notification/info', { message: i18n.t('Failed to precreate ACLs on switch <code>{id}</code>.', { id }) })
        })
      })
    })
  }

  return {
    useSearch,
    tableRef,
    onBulkExport,
    onInvalidateCache,
    onRemove,
    ...router,
    ...selected,
    ...toRefs(search),
    switchGroups,
    switchTemplates,
    onPrecreateAcls,
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
