<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ $t('Certificates') }}</h4>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch" :disabled="!isServiceAlive">
        <b-dropdown :text="$t('New Certificate')" variant="outline-primary" :disabled="!isServiceAlive || profiles.length === 0">
          <b-dropdown-header>{{ $t('Choose Certificate Authority - Template') }}</b-dropdown-header>
          <b-dropdown-item v-for="profile in profilesSorted" :key="profile.ID" :to="{ name: 'newPkiCert', params: { profile_id: profile.ID } }">{{ profile.ca_name }} - {{ profile.name }}</b-dropdown-item>
        </b-dropdown>
        <base-button-service
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
          <span class="float-right text-right">
            <b-button
              size="sm" variant="outline-primary" class="my-1 mr-1"
              :disabled="!isServiceAlive"
              @click.stop.prevent="goToClone({ id: item.ID, ...item })"
            >{{ $t('Clone') }}</b-button>
            <button-certificate-download :disabled="!isServiceAlive" :id="item.ID" class="my-1 mr-1" />
            <button-certificate-email :disabled="!isServiceAlive" :id="item.ID" class="my-1 mr-1" />
            <button-certificate-revoke :disabled="!isServiceAlive" :id="item.ID" class="my-1 mr-1" @change="reSearch" />
          </span>
        </template>
        <template #cell(ca_name)="{ item }">
          <router-link :is="(isServiceAlive) ? 'router-link' : 'span'" :to="{ name: 'pkiCa', params: { id: item.ca_id } }">{{ item.ca_name }}</router-link>
        </template>
        <template #cell(profile_name)="{ item }">
          <router-link :is="(isServiceAlive) ? 'router-link' : 'span'" :to="{ name: 'pkiProfile', params: { id: item.profile_id } }">{{ item.profile_name }}</router-link>
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
import {
  ButtonCertificateDownload,
  ButtonCertificateEmail,
  ButtonCertificateRevoke
} from './'

const components = {
  BaseButtonConfirm,
  BaseButtonService,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty,
  ButtonCertificateDownload,
  ButtonCertificateEmail,
  ButtonCertificateRevoke
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
