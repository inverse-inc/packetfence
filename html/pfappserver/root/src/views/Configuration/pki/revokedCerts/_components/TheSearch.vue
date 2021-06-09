<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ $t('Revoked Certificates') }}</h4>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch">
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
        <template #cell(ca_name)="{ item }">
          <router-link :to="{ name: 'pkiCa', params: { id: item.ca_id } }">{{ item.ca_name }}</router-link>
        </template>
        <template #cell(profile_name)="{ item }">
          <router-link :to="{ name: 'pkiProfile', params: { id: item.profile_id } }">{{ item.profile_name }}</router-link>
        </template>
        <template #cell(crl_reason)="{ item }">
          {{ revokeReasons.find(reason => ~~reason.value === ~~item.crl_reason).text }}
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

import { ref, toRefs } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import { useSearch, useRouter } from '../_composables/useCollection'
import { revokeReasons } from '../../config'

const setup = (props, context) => {

  const search = useSearch()
  const {
    items,
    visibleColumns
  } = toRefs(search)

  const { root: { $router } = {} } = context

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

  return {
    useSearch,
    tableRef,
    onBulkExport,
    revokeReasons,
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
          <h4 class="mb-0">{{ $t('Revoked Certificates') }}</h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <pf-button-service service="pfpki" class="ml-1" restart start stop :disabled="isLoading" @start="init" @restart="init"></pf-button-service>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :is-loading="state.isLoading">{{ $t('No revoked certificates found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(ca_name)="item">
        <router-link :to="{ name: 'pkiCa', params: { id: item.ca_id } }">{{ item.ca_name }}</router-link>
      </template>
      <template v-slot:cell(profile_name)="item">
        <router-link :to="{ name: 'pkiProfile', params: { id: item.profile_id } }">{{ item.profile_name }}</router-link>
      </template>
      <template v-slot:cell(crl_reason)="item">
        {{ revokeReasons.find(reason => ~~reason.value === ~~item.crl_reason).text }}
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
} from '../_config/pki/revokedCert'
import {
  revokeReasons
} from '../_config/pki/'

export default {
  name: 'pki-revoked-certs-list',
  components: {
    pfButtonService,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this),
      revokeReasons,
      profiles: []
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_pkis/isRevokedCertLoading']
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_pkis/allProfiles').then(profiles => {
        this.profiles = (profiles || []).sort((a, b) => { // sort profiles
          return (a.ca_name === b.ca_name)
            ? a.name.localeCompare(b.name)
            : a.ca_name.localeCompare(b.ca_name)
        })
      })
    }
  },
  created () {
    this.init()
  }
}
</script>
-->