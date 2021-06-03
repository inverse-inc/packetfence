<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-flex align-items-center">
        {{ $t('Connection Profiles') }}
        <base-button-help class="text-black-50 ml-1" url="PacketFence_Installation_Guide.html#_connection_profiles" />
      </h4>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch">
        <b-button variant="outline-primary" @click="goToNew">{{ $t('New Connection Profile') }}</b-button>
      </base-search>
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
        @row-clicked="goToItem"
        @row-selected="onRowSelected"
        @items-sorted="onSorted"
      >
        <template v-slot:empty>
          <slot name="emptySearch" v-bind="{ isLoading }">
              <pf-empty-table :is-loading="isLoading">{{ $t('No results found') }}</pf-empty-table>
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
        <template #cell(status)="{ item }">
          <toggle-status :value="item.status" :disabled="item.not_deletable || isLoading"
            :item="item" @input="item.status = $event" />
        </template>
        <template #head(buttons)>
          <base-search-input-columns
            :disabled="isLoading"
            :value="columns"
            @input="setColumns"
          />
        </template>
        <template #cell(buttons)="{ item }">
          <span class="float-right text-nowrap text-right"
            @click.stop.prevent
          >
            <base-button-confirm v-if="!item.not_deletable"
              size="sm" variant="outline-danger" class="my-1 mr-1" reverse
              :disabled="isLoading"
              :confirm="$t('Delete Connection Profile?')"
              @click="onRemove(item.id)"
            >{{ $t('Delete') }}</base-button-confirm>
            <b-button
              size="sm" variant="outline-secondary" class="mr-1"
              @click.stop.prevent="goToPreview(item)"
            >{{ $t('Preview') }} <icon class="ml-1" name="external-link-alt"></icon></b-button>
            <b-button
              size="sm" variant="outline-primary" class="mr-1"
              @click.stop.prevent="goToClone(item)"
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
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableSortable
} from '@/components/new/'
import pfEmptyTable from '@/components/pfEmptyTable'
import ToggleStatus from './ToggleStatus'

const components = {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableSortable,
  pfEmptyTable,
  ToggleStatus
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

  const router = useRouter($router)
  const {
    goToPreview
  } = router

  const tableRef = ref(null)
  const selected = useBootstrapTableSelected(tableRef, items)
  const {
    selectedItems
  } = toRefs(selected)

  const onBulkExport = () => {
    const filename = `${$router.currentRoute.path.slice(1).replace('/', '-')}-${(new Date()).toISOString()}.csv`
    const csv = useTableColumnsItems(visibleColumns.value, selectedItems.value)
    useDownload(filename, csv, 'text/csv')
  }

  const onRemove = id => {
    $store.dispatch('$_admin_roles/deleteAdminRole', id)
      .then(() => {
        reSearch()
      })
  }

  const {
    sortItems
  } = useStore(props, context)

  const onSorted = _items => {
    items.value = _items
    sortItems(items.value.map(item => item.id))
      .then(() => reSearch())
  }

  return {
    useSearch,
    tableRef,
    onRemove,
    onBulkExport,
    ...router,
    ...selected,
    ...toRefs(search),
    goToPreview,
    onSorted
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



<!--


<template>
  <b-card no-body>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
      :sortable="true"
      @sort="sort"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0">
            {{ $t('Connection Profiles') }}
            <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_connection_profiles" />
          </h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-button variant="outline-primary" :to="{ name: 'newConnectionProfile' }">{{ $t('New Connection Profile') }}</b-button>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :is-loading="state.isLoading">{{ $t('No connection profiles found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Connection Profile?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-secondary" class="mr-1" @click.stop.prevent="preview(item)">{{ $t('Preview') }} <icon class="ml-1" name="external-link-alt"></icon></b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
      <template v-slot:cell(status)="item">
         <toggle-status :value="item.status" :disabled="item.not_deletable || isLoading"
          :item="item" :searchable-store-name="$refs.pfConfigList.searchableStoreName" />
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonHelp from '@/components/pfButtonHelp'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { config } from '../_config/connectionProfile'
import { ToggleStatus } from '@/views/Configuration/connectionProfiles/_components/'

export default {
  name: 'connection-profiles-list',
  components: {
    pfButtonDelete,
    pfButtonHelp,
    pfConfigList,
    pfEmptyTable,
    ToggleStatus
  },
  data () {
    return {
      config: config(this)
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_connection_profiles/isLoading']
    }
  },
  methods: {
    preview (item) {
      window.open(`/portal_preview/captive-portal?PORTAL=${item.id}`, '_blank')
    },
    clone (item) {
      this.$router.push({ name: 'cloneConnectionProfile', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_connection_profiles/deleteConnectionProfile', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    },
    sort (items) {
      this.$store.dispatch('$_connection_profiles/sortConnectionProfiles', items.map(item => item.id)).then(() => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Connection profiles resorted.') })
      })
    }
  }
}
</script>
-->