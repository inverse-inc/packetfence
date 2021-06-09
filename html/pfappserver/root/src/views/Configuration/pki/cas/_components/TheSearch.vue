<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ $t('Certificate Authorities') }}</h4>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch">
        <b-button :disabled="isLoading || !isServiceAlive"
          variant="outline-primary" @click="goToNew">{{ $t('New Certificate Authority') }}</b-button>
        <base-button-service
          service="pfpki" restart start stop
          class="ml-1" />
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
        <template #head(buttons)>
          <base-search-input-columns
            :disabled="isLoading"
            :value="columns"
            @input="setColumns"
          />
        </template>
        <template #cell(buttons)="{ item }">
          <span class="float-right text-nowrap text-right">
            <b-button
              size="sm" variant="outline-primary" class="mr-1"
              @click.stop.prevent="goToClone({ id: item.ID, ...item })"
            >{{ $t('Clone') }}</b-button>
            <b-button
              size="sm" variant="outline-primary" class="mr-1 text-nowrap"
              @click.stop.prevent="onClipboard(item)"
            >{{ $t('Copy Certificate') }}</b-button>
            <b-button
              size="sm" variant="outline-primary" class="mr-1 text-nowrap"
              :to="{ name: 'newPkiProfile', params: { ca_id: item.ID } }"
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
          <b-dropdown-item @click="onBulkExport">Export to CSV</b-dropdown-item>
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
  BaseSearchInputColumns
} from '@/components/new/'
import pfEmptyTable from '@/components/pfEmptyTable'

const components = {
  BaseButtonConfirm,
  BaseButtonService,
  BaseSearch,
  BaseSearchInputColumns,
  pfEmptyTable
}

import { computed, ref, toRefs } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import { useSearch, useRouter } from '../_composables/useCollection'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const search = useSearch()
  const {
    items,
    visibleColumns
  } = toRefs(search)

  const { root: { $router, $store } = {} } = context

  const isServiceAlive = computed(() => {
    const { state: { services: { cache: { pfpki: { alive } = {} } = {} } = {} } = {} } = $store
    return alive
  })

  const router = useRouter($router)

  const tableRef = ref(null)
  const selected = useBootstrapTableSelected(tableRef, items)
  const {
    selectedItems
  } = selected

  const onClipboard = item => {
    $store.dispatch('$_pkis/getCa', item.ID).then(ca => {
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

  return {
    useSearch,
    isServiceAlive,
    tableRef,
    onClipboard,
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


<!--
<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0">{{ $t('Certificate Authorities') }}</h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-button variant="outline-primary" :to="{ name: 'newPkiCa' }" :disabled="!isServiceAlive">{{ $t('New Certificate Authority') }}</b-button>
        <pf-button-service service="pfpki" class="ml-1" restart start stop :disabled="isLoading"></pf-button-service>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :is-loading="state.isLoading">{{ $t('No certificate authorities found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right">
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1 text-nowrap" @click.stop.prevent="clipboard(item)">{{ $t('Copy Certificate') }}</b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1 text-nowrap" :to="{ name: 'newPkiProfile', params: { ca_id: item.ID } }">{{ $t('New Template') }}</b-button>
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonService from '@/components/pfButtonService'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  config
} from '../_config/pki/ca'

export default {
  name: 'pki-cas-list',
  components: {
    pfButtonService,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this)
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_pkis/isLoading']
    },
    isServiceAlive () {
      const { $store: { state: { services: { cache: { pfpki = {} } = {} } = {} } = {} } = {} } = this
      return pfpki.alive
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'clonePkiCa', params: { id: item.ID } })
    },
    clipboard (item) {
      this.$store.dispatch('$_pkis/getCa', item.ID).then(ca => {
        try {
          navigator.clipboard.writeText(ca.cert).then(() => {
            this.$store.dispatch('notification/info', { message: this.$i18n.t('<code>{cn}</code> certificate copied to clipboard', ca) })
          }).catch(() => {
            this.$store.dispatch('notification/danger', { message: this.$i18n.t('Could not copy <code>{cn}</code> certificate to clipboard.', ca) })
          })
        } catch (e) {
          this.$store.dispatch('notification/danger', { message: this.$i18n.t('Clipboard not supported.') })
        }
      })
    }
  }
}
</script>
-->