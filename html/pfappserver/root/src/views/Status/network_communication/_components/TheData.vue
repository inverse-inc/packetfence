<template>
  <b-row class="mt-3">
    <b-col cols="12">
      <b-tabs lazy>
        <b-tab title="Data">
          <base-data-table />
        </b-tab>
        <b-tab title="Flows" active>
          <base-data-flows :device="device" />
        </b-tab>
        <b-tab title="Hosts">
          <base-data-hosts />
        </b-tab>
        <b-tab title="Protocols">
          <base-data-protocols />
        </b-tab>
      </b-tabs>
    </b-col>
  </b-row>
</template>

<script>
import BaseDataFlows from './BaseDataFlows'
import BaseDataTable from './BaseDataTable'
import BaseDataProtocols from './BaseDataProtocols'
import BaseDataHosts from './BaseDataHosts'

const components = {
  BaseDataFlows,
  BaseDataTable,
  BaseDataProtocols,
  BaseDataHosts,
}

const props = {
  device: {
    type: String
  }
}

import { computed } from '@vue/composition-api'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const isLoading = computed(() => $store.getters['$_fingerbank_communication/isLoading'])
  const items = computed(() => $store.getters['$_fingerbank_communication/tabular'])

  return {
    isLoading,
    items,
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
