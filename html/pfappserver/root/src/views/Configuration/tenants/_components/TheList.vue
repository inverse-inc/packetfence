<template>
  <b-card no-body>
    <b-card-header>
      <div class="float-right">
        <base-input-toggle-advanced-mode
          v-model="advancedMode"
          :disabled="isLoading"
          label-left
        />
      </div>
      <h4 class="mb-0">
        {{ $t('Tenants') }}
        <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_tenants" />
      </h4>
    </b-card-header>
    <div class="card-body">
      <transition name="fade" mode="out-in">
        <div v-if="advancedMode">
          <b-form @submit.prevent="onSearchAdvanced" @reset.prevent="onSearchReset">
            <base-search-input-advanced
              v-model="conditionAdvanced"
              :disabled="isLoading"
              :fields="fields"
              @reset="onSearchReset"
              @search="onSearchAdvanced"
            />
            <b-container fluid class="text-right mt-3 px-0">
              <b-button class="mr-1" type="reset" variant="secondary" :disabled="isLoading">{{ $t('Clear') }}</b-button>
              <base-button-save-search
                save-search-namespace="tenants-advanced"
                v-model="conditionAdvanced"
                :disabled="isLoading"
                @search="onSearchAdvanced"
              />
            </b-container>
          </b-form>
        </div>
        <base-search-input-basic v-else
          save-search-namespace="tenants-basic"
          v-model="conditionBasic"
          :disabled="isLoading"
          :placeholder="$t('Search by name or description')"
          @reset="onSearchReset"
          @search="onSearchBasic"
        />
      </transition>
    </div>
    <div class="card-body pt-0">
      <b-row>
        <b-col cols="auto" class="mr-auto mb-3">
          <b-button variant="outline-primary" :to="{ name: 'newTenant' }">{{ $t('New Tenant') }}</b-button>
        </b-col>
      </b-row>
      <b-row align-h="end" align-v="center">
        <b-col>
          <base-search-input-columns
            v-model="columns"
            :disabled="isLoading"
          />
        </b-col>
        <b-col cols="auto">
          <b-container fluid>
            <b-row align-v="center">
              <base-search-input-limit
                v-model="limit"
                size="md"
                :limits="limits"
                :disabled="isLoading"
              />
              <base-search-input-page
                v-model="page"
                :limit="limit"
                :total-rows="totalRows"
                :disabled="isLoading"
              />
              <base-button-export-csv
                class="mb-3" size="md"
                :filename="`${$route.path.slice(1).replace('/', '-')}.csv`"
                :disabled="isLoading"
                :columns="columns" :data="items"
              />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table
        :busy="isLoading"
        :hover="items.length > 0"
        :items="items"
        :fields="visibleColumns"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        @sort-changed="onSortChanged"
        @row-clicked="onRowClicked"
        show-empty
        responsive
        no-local-sorting
        sort-icon-left
        fixed
        striped
      >
        <template v-slot:empty>
          <slot name="emptySearch" v-bind="{ isLoading }">
              <pf-empty-table :is-loading="isLoading">{{ $t('No results found') }}</pf-empty-table>
          </slot>
        </template>
        <template v-slot:cell(buttons)="{ item }">
          <span class="float-right text-nowrap text-right">
            <base-button-confirm v-if="!item.not_deletable"
              size="sm" variant="outline-danger" class="my-1 mr-1" reverse
              :disabled="isLoading"
              :confirm="$t('Delete Tenant?')"
              @click="onRemove(item.id)"
            >{{ $t('Delete') }}</base-button-confirm>
            <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="onClone(item.id)">{{ $t('Clone') }}</b-button>
          </span>
        </template>
      </b-table>
    </div>
  </b-card>
</template>
<script>
import {
  BaseButtonConfirm,
  BaseButtonExportCsv,
  BaseButtonSaveSearch,
  BaseInputToggleAdvancedMode,
  BaseSearchInputBasic,
  BaseSearchInputAdvanced,
  BaseSearchInputColumns,
  BaseSearchInputLimit,
  BaseSearchInputPage,
} from '@/components/new/'
import pfButtonHelp from '@/components/pfButtonHelp'
import pfEmptyTable from '@/components/pfEmptyTable'

const components = {
  BaseButtonConfirm,
  BaseButtonExportCsv,
  BaseButtonSaveSearch,
  BaseInputToggleAdvancedMode,
  BaseSearchInputBasic,
  BaseSearchInputAdvanced,
  BaseSearchInputColumns,
  BaseSearchInputLimit,
  BaseSearchInputPage,
  pfButtonHelp,
  pfEmptyTable
}

import { onMounted, ref } from '@vue/composition-api'
import { useSearch, useRouter } from '../_composables/useCollection'

const defaultCondition = () => ([{ values: [{ field: 'name', op: 'contains', value: null }] }])

const setup = (props, context) => {

  const { root: { $router, $store } = {} } = context

  const advancedMode = ref(false)
  const conditionBasic = ref(null)
  const conditionAdvanced = ref(defaultCondition()) // default
  const search = useSearch(props, context)
  const {
    doReset,
    doSearchString,
    doSearchCondition,
    reSearch
  } = search

  onMounted(() => {
    const { currentRoute: { query: { query } = {} } = {} } = $router
    if (query) {
      const parsedQuery = JSON.parse(query)
      switch(parsedQuery.constructor) {
        case Array: // advanced search
          conditionAdvanced.value = parsedQuery
          advancedMode.value = true
          doSearchCondition(conditionAdvanced.value)
          break
        case String: // basic search
        default:
          conditionBasic.value = parsedQuery
          advancedMode.value = false
          doSearchString(conditionBasic.value)
          break
      }
    }
    else
      doReset()
  })

  const _setQueryParam = query => {
    const { currentRoute } = $router
    $router.replace({ ...currentRoute, query: { query } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
  }
  const _clearQueryParam = () => _setQueryParam()

  const onSearchBasic = () => {
    if (conditionBasic.value) {
      doSearchString(conditionBasic.value)
      _setQueryParam(JSON.stringify(conditionBasic.value))
    }
    else
      doReset()
  }

  const onSearchAdvanced = () => {
    if (conditionAdvanced.value) {
      doSearchCondition(conditionAdvanced.value)
      _setQueryParam(JSON.stringify(conditionAdvanced.value))
    }
    else
      doReset()
  }

  const onSearchReset = () => {
    conditionBasic.value = null
    conditionAdvanced.value = defaultCondition() // dereference
    _clearQueryParam()
    doReset()
  }

  const onRowClicked = item => {
    const {
      goToItem
    } = useRouter(props, context)
    goToItem(item)
  }

  const onClone = id => {
    $router.push({ name: 'cloneTenant', params: { id } })
  }

  const onRemove = id => {
    $store.dispatch('$_tenants/deleteTenant', id)
      .then(() => reSearch())
  }

  return {
    advancedMode,
    conditionBasic,
    onSearchBasic,
    conditionAdvanced,
    onSearchAdvanced,
    onSearchReset,
    onRowClicked,
    onClone,
    onRemove,
    ...search
  }
}

// @vue/component
export default {
  name: 'the-list',
  inheritAttrs: false,
  components,
  setup
}
</script>
