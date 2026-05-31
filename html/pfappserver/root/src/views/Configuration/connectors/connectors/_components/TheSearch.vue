<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-flex align-items-center mb-0">
        {{ $t('Connector') }}
      </h4>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch">
        <b-button variant="outline-primary" @click="goToNew">{{ $t('New Connector') }}</b-button>
      </base-search>
      <base-table-sortable ref="tableRef"
        :busy="isLoading"
        :hover="itemsWithStatus.length > 0"
        :items="itemsWithStatus"
        :fields="visibleColumns"
        class="mb-0"
        show-empty
         fixed
        striped
        selectable
        @row-clicked="goToItem"
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
        <template v-slot:cell(networks)="item">
          <b-badge v-for="(network, index) in item.item.networks" :key="index" class="mr-1" variant="secondary">{{ network }}</b-badge>
        </template>
        <template v-slot:cell(status)="data">
          <icon name="circle"
            v-b-tooltip.hover
            :title="statusTooltip(data.item.status)"
            :class="{
              'text-success': data.item.status === 'up',
              'text-warning': data.item.status === 'unknown',
              'text-danger': data.item.status === 'down',
            }"
          />
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
              :confirm="$t('Delete Connector?')"
              @click="onRemove(item.id)"
            >{{ $t('Delete') }}</base-button-confirm>
            <b-button
              size="sm" variant="outline-primary" class="mr-1"
              @click.stop.prevent="goToClone(item)"
            >{{ $t('Clone') }}</b-button>
            <b-button
              size="sm" variant="outline-primary" class="mr-1"
              :disabled="isLoading"
              @click.stop.prevent="onCopyInstallCommand(item)"
            >{{ $t('Install Command') }}</b-button>
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
  </b-card>
</template>
<script>
import {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty,
  BaseTableSortable
} from '@/components/new/'

const components = {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty,
  BaseTableSortable
}

import { ref, toRefs, onMounted, onUnmounted, reactive, computed } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import i18n from '@/utils/locale'
import api from '../_api'
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
    deleteItem,
    sortItems,
    getConnectorsStatus
  } = useStore($store)

  const router = useRouter($router)

  const connectorStatuses = reactive({})
  let statusInterval = null

  const fetchStatuses = () => {
    getConnectorsStatus().then(statuses => {
      statuses.forEach(s => {
        connectorStatuses[s.id] = s.status
      })
    }).catch(() => {
      // gracefully ignore errors
    })
  }

  onMounted(() => {
    fetchStatuses()
    statusInterval = setInterval(fetchStatuses, 10000)
  })

  onUnmounted(() => {
    if (statusInterval) {
      clearInterval(statusInterval)
      statusInterval = null
    }
  })

  const itemsWithStatus = computed(() => {
    return items.value.map(item => ({
      ...item,
      status: connectorStatuses[item.id] || 'unknown'
    }))
  })

  const statusTooltip = (status) => {
    switch (status) {
      case 'up': return i18n.t('Connected')
      case 'down': return i18n.t('Disconnected')
      default: return i18n.t('Unknown')
    }
  }

  const tableRef = ref(null)
  const selected = useBootstrapTableSelected(tableRef, itemsWithStatus)
  const {
    selectedItems
  } = selected

  const onBulkExport = () => {
    const filename = `${$router.currentRoute.path.slice(1).replace('/', '-')}-${(new Date()).toISOString()}.csv`
    const csv = useTableColumnsItems(visibleColumns.value, selectedItems.value)
    useDownload(filename, csv, 'text/csv')
  }

  const onCopyInstallCommand = (item) => {
    api.item(item.id).then(connector => {
      const server = $store.getters['system/hostname'] || window.location.hostname
      const command = `curl -sL https://proxy.saas.packetfence.com/connector-remote-install.sh | bash -s -- ${connector.id} ${connector.secret} ${server}`
      try {
        navigator.clipboard.writeText(command).then(() => {
          $store.dispatch('notification/info', { message: i18n.t('Install command copied to clipboard.') })
        }).catch(() => {
          $store.dispatch('notification/danger', { message: i18n.t('Could not copy install command to clipboard.') })
        })
      } catch (e) {
        $store.dispatch('notification/danger', { message: i18n.t('Clipboard not supported.') })
      }
    }).catch(() => {
      $store.dispatch('notification/danger', { message: i18n.t('Could not fetch connector details.') })
    })
  }

  const onRemove = id => {
    deleteItem({ id })
      .then(() => reSearch())
  }

  const onSorted = _items => {
    items.value = _items
    sortItems({ items: items.value.map(item => item.id) })
      .then(() => reSearch())
  }

  return {
    useSearch,
    itemsWithStatus,
    statusTooltip,
    tableRef,
    onCopyInstallCommand,
    onRemove,
    onSorted,
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
