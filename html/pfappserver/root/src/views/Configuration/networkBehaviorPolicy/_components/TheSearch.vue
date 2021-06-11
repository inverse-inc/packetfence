<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ $t('Network Behaviour Policies') }}</h4>
    </b-card-header>
    <div class="card-body">
      <div v-if="!canUseNbaEndpoints"
        class="alert alert-warning"
      >{{ $t(`Your Fingerbank account currently doesn't have access to the network behavior analysis API endpoints. Get in touch with info@inverse.ca for a quote. Without these API endpoints, you will not be able to use the anomaly detection feature.`) }}</div>

      <base-search :use-search="useSearch">
        <b-button variant="outline-primary" @click="goToNew">{{ $t('New Network Behaviour Policy') }}</b-button>
      </base-search>
      <b-table ref="tableRef"
        :busy="isLoading"
        :hover="items.length > 0"
        :items="items"
        :fields="visibleColumns"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        class="mb-0"
        show-empty
        no-local-sorting
        no-sort-reset
        sort-icon-left
        fixed
        striped
        selectable
        @row-clicked="goToItem"
        @row-selected="onRowSelected"
        @sort-changed="setSort"
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
            :item="item" :collection="collection" @input="item.status = $event" />
        </template>
        <template #cell(buttons)="{ item }">
          <span class="float-right text-nowrap text-right"
            @click.stop.prevent
          >
            <base-button-confirm v-if="!item.not_deletable"
              size="sm" variant="outline-danger" class="my-1 mr-1" reverse
              :disabled="isLoading"
              :confirm="$t('Delete Policy?')"
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
  BaseSearchInputColumns
} from '@/components/new/'
import pfEmptyTable from '@/components/pfEmptyTable'
import ToggleStatus from './ToggleStatus'

const components = {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  pfEmptyTable,
  ToggleStatus
}

const props = {
  collection: {
    type: Object
  }
}

import { ref, toRefs } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import { useSearch, useStore, useRouter } from '../_composables/useCollection'

const setup = (props, context) => {

  const {
    collection
  } = toRefs(props)

  const { root: { $store, $router } = {} } = context

  const canUseNbaEndpoints = ref(false)
  $store.dispatch('$_fingerbank/getCanUseNbaEndpoints').then(info => {
    canUseNbaEndpoints.value = info["result"]
  })

  const search = useSearch()
  const {
    reSearch
  } = search
  const {
    items,
    visibleColumns
  } = toRefs(search)

  const router = useRouter($router)
  const {
    goToPreview
  } = router

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

  const {
    deleteItem
  } = useStore(props, context)

  const onRemove = id => {
    deleteItem({ ...collection.value, id })
      .then(() => reSearch())
  }

  return {
    canUseNbaEndpoints,
    useSearch,
    tableRef,
    ...router,
    ...selected,
    ...toRefs(search),
    goToPreview,
    onBulkExport,
    onRemove
  }
}

// @vue/component
export default {
  name: 'the-search',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>


<!--
<template>
  <b-card no-body>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0">
            {{ $t('Network Behavior Policy') }}
          </h4>
        </b-card-header>
        <b-card-header v-if="!canUseNbaEndpoints">
          <template>
          <div class="alert alert-warning">{{ $t(`Your Fingerbank account currently doesn't have access to the network behavior analysis API endpoints. Get in touch with info@inverse.ca for a quote. Without these API endpoints, you will not be able to use the anomaly detection feature.`) }}</div>
          </template>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-button variant="outline-primary" :to="{ name: 'newNetworkBehaviorPolicy' }">{{ $t('New Network Behavior Policy') }}</b-button>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :is-loading="state.isLoading">{{ $t('No Network Behavior Policies found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Network Behavior Policy?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
      <template v-slot:cell(status)="item">
        <toggle-status :value="item.status"
          :disabled="isLoading"
          :item="item" />
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { config } from '../_config/networkBehaviorPolicy'
import { ToggleStatus } from '@/views/Configuration/networkBehaviorPolicy/_components/'

export default {
  name: 'network-behavior-policies-list',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable,
    ToggleStatus
  },
  data () {
    return {
      config: config(this),
      canUseNbaEndpoints: false,
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_network_behavior_policies/isLoading']
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneNetworkBehaviorPolicy', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_network_behavior_policies/deleteNetworkBehaviorPolicy', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    },
    init () {
      this.$store.dispatch('$_fingerbank/getCanUseNbaEndpoints').then(info => {
        this.canUseNbaEndpoints = info["result"]
      })
    }
  },
  created () {
    this.init()
  }
}
</script>
-->