<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ $t('Certificates') }}</h4>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch">
        <b-dropdown :text="$t('New Certificate')" variant="outline-primary" :disabled="!isServiceAlive || profiles.length === 0">
          <b-dropdown-header>{{ $t('Choose Certificate Authority - Template') }}</b-dropdown-header>
          <b-dropdown-item v-for="profile in profilesSorted" :key="profile.ID" :to="{ name: 'newPkiCert', params: { profile_id: profile.ID } }">{{ profile.ca_name }} - {{ profile.name }}</b-dropdown-item>
        </b-dropdown>
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
            <button-certificate-download :id="item.ID" class="mr-1" />
            <button-certificate-email :id="item.ID" class="mr-1" />
            <button-certificate-revoke :id="item.ID" class="mr-1" @change="reSearch" />
          </span>
        </template>
        <template #cell(ca_name)="{ item }">
          <router-link :to="{ name: 'pkiCa', params: { id: item.ca_id } }">{{ item.ca_name }}</router-link>
        </template>
        <template #cell(profile_name)="{ item }">
          <router-link :to="{ name: 'pkiProfile', params: { id: item.profile_id } }">{{ item.profile_name }}</router-link>
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
import {
  ButtonCertificateDownload,
  ButtonCertificateEmail,
  ButtonCertificateRevoke
} from './'
import pfEmptyTable from '@/components/pfEmptyTable'

const components = {
  BaseButtonConfirm,
  BaseButtonService,
  BaseSearch,
  BaseSearchInputColumns,
  ButtonCertificateDownload,
  ButtonCertificateEmail,
  ButtonCertificateRevoke,
  pfEmptyTable
}

import { computed, ref, toRefs } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import { useSearch, useRouter } from '../_composables/useCollection'

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

  $store.dispatch('$_pkis/allProfiles')
  const profiles = computed(() => $store.getters['$_pkis/profiles'] || [])
  const profilesSorted = computed(() => {
    return Array.prototype.slice.call(profiles.value)
      .sort((a, b) => {
        return (a.ca_name === b.ca_name)
          ? a.name.localeCompare(b.name)
          : a.ca_name.localeCompare(b.ca_name)
      }) // sort profiles by 'name'
  })

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
    isServiceAlive,
    profiles,
    profilesSorted,
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

<!--
<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0">{{ $t('Certificates') }}</h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-dropdown :text="$t('New Certificate')" variant="outline-primary" :disabled="profiles.length === 0">
          <b-dropdown-header>{{ $t('Choose Certificate Authority - Template') }}</b-dropdown-header>
          <b-dropdown-item v-for="profile in sortedProfiles" :key="profile.ID" :to="{ name: 'newPkiCert', params: { profile_id: profile.ID } }">{{ profile.ca_name }} - {{ profile.name }}</b-dropdown-item>
        </b-dropdown>
        <pf-button-service service="pfpki" class="ml-1" restart start stop :disabled="isLoading" @start="init" @restart="init"></pf-button-service>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :is-loading="state.isLoading">{{ $t('No certificates found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(ca_name)="item">
        <router-link :to="{ name: 'pkiCa', params: { id: item.ca_id } }">{{ item.ca_name }}</router-link>
      </template>
      <template v-slot:cell(profile_name)="item">
        <router-link :to="{ name: 'pkiProfile', params: { id: item.profile_id } }">{{ item.profile_name }}</router-link>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right">
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <button-certificate-download :id="item.ID" />
          <b-button v-if="item.mail" size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="email(item)">{{ $t('Email') }}</b-button>
          <button-certificate-revoke :id="item.ID" />
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import {
  ButtonCertificateDownload,
  ButtonCertificateRevoke
} from '@/views/Configuration/pki/certs/_components/'
import pfButtonService from '@/components/pfButtonService'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  config,
  revoke,
  download
} from '../_config/pki/cert'

export default {
  name: 'pki-certs-list',
  components: {
    ButtonCertificateDownload,
    ButtonCertificateRevoke,
    pfButtonService,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this),
      revoke, // ../_config/pki/cert
      download // ../_config/pki/cert
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_pkis/isCertLoading']
    },
    profiles () {
      return this.$store.getters['$_pkis/profiles'] || []
    },
    sortedProfiles () {
      return Array.prototype.slice.call(this.profiles).sort((a, b) => {
        return (a.ca_name === b.ca_name)
          ? a.name.localeCompare(b.name)
          : a.ca_name.localeCompare(b.ca_name)
      }) // sort profiles by 'name'
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_pkis/allProfiles')
    },
    clone (item) {
      this.$router.push({ name: 'clonePkiCert', params: { id: item.ID } })
    },
    email (item) {
      const { ID, mail } = item
      if (mail) {
        this.$store.dispatch('$_pkis/emailCert', ID).then(() => {
          this.$store.dispatch('notification/info', { message: this.$i18n.t('Certificate <code>{cn}</code> emailed to <code>{mail}</code>.', item) })
        }).catch(e => {
          this.$store.dispatch('notification/danger', { message: this.$i18n.t('Could not email certificate <code>{cn}</code> to <code>{mail}</code>: ', item) + e })
        })
      }
    }
  },
  created () {
    this.init()
  }
}
</script>
-->