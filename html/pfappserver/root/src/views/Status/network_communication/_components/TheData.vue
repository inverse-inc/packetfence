<template>
  <div>
    <b-row class="mt-3">
      <b-col cols="12">
        <div class="d-flex justify-content-md-end">
          <base-search-input-limit
            :value="limit" @input="setLimit"
            size="md"
            :limits="limits"
            :disabled="isLoading"
          />
          <base-search-input-page
            :value="page" @input="setPage"
            class="ml-3"
            :limit="limit"
            :total-rows="totalRows"
            :disabled="isLoading"
          />
        </div>
      </b-col>
    </b-row>
    <b-row>
      <b-col cols="12">
        <b-tabs lazy>
          <b-tab title="Flows">
            <base-data-flows v-bind="{ isLoading, items }" />
          </b-tab>
          <b-tab title="Data">
            <base-data-table />
          </b-tab>
          <b-tab title="Protocols">
            <base-data-protocols v-bind="{ isLoading, items }" />
          </b-tab>
          <b-tab title="Hosts">
            <base-data-hosts v-bind="{ isLoading, items }" />
          </b-tab>
        </b-tabs>
      </b-col>
    </b-row>
  </div>
</template>

<script>
import BaseDataFlows from './BaseDataFlows'
import BaseDataTable from './BaseDataTable'
import BaseDataProtocols from './BaseDataProtocols'
import BaseDataHosts from './BaseDataHosts'
import {
  BaseSearchInputLimit,
  BaseSearchInputPage,
} from '@/components/new/'

const components = {
  BaseDataFlows,
  BaseDataTable,
  BaseDataProtocols,
  BaseDataHosts,

  BaseSearchInputLimit,
  BaseSearchInputPage,
}

const props = {
  selectedCategories: {
    type: Array
  },
  selectedDevices: {
    type: Array
  },
  selectedProtocols: {
    type: Array
  },
  selectedHosts: {
    type: Array
  },
}

import { toRefs, watch } from '@vue/composition-api'
import { useSearch } from '../_composables/useCollection'

const setup = props => {

  const {
    selectedCategories,
    selectedDevices,
    selectedProtocols,
    selectedHosts,
  } = toRefs(props)

  const search = useSearch()
  const {
    reSearch
  } = search

  watch([selectedCategories, selectedDevices, selectedProtocols, selectedHosts], () => {
    search.requestInterceptor = request => {
      return {
        ...request,
        selectedCategories: selectedCategories.value,
        selectedDevices: selectedDevices.value,
        selectedProtocols: selectedProtocols.value,
        selectedHosts: selectedHosts.value,
      }
    }
    reSearch()
  }, { immediate: true })

  return {
    ...toRefs(search),
    search
  }
}

// @vue/component
export default {
  name: 'the-data',
  components,
  props,
  setup
}
</script>