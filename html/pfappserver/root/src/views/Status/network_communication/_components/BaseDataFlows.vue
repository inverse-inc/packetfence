<template>
  <b-card no-body>
    <b-card-header>
      Flows
    </b-card-header>
    <b-tabs small v-model="tabIndex">
      <b-tab lazy>
        <template #title>
          {{ $i18n.t('All') }}
        </template>
      </b-tab>
      <b-tab v-for="(devices, i) in collections" :key="`tab-${i}`"
        lazy>
        <template #title>
          <span v-for="device of devices" :key="device.mac">
            {{ device.mac }} <b-badge pill variant="primary" class="ml-1">{{ device.count }}</b-badge>
          </span>
        </template>
      </b-tab>

      <base-data-flow :devices="devices" />
    </b-tabs>
  </b-card>
</template>
<script>
import BaseDataFlow from './BaseDataFlow'
const components = {
  BaseDataFlow
}

import { computed, ref, watch } from '@vue/composition-api'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const isLoading = computed(() => $store.getters['$_fingerbank_communication/isLoading'])
  const items = computed(() => $store.getters['$_fingerbank_communication/tabular'])
  const itemsByMacs = computed(() => {
    return macs => items.value.filter(item => macs.indexOf(item.mac) > -1)
  })
  const byDevice = computed(() => $store.getters['$_fingerbank_communication/byDevice'])

  const collections = ref([])
  watch(byDevice, () => {
    collections.value = Object.entries(byDevice.value)
      .map(([mac, data]) => ({ mac, ...data }))
      .sort((a, b) => a.mac.localeCompare(b.mac))
      .map(item => ([ item ]))
  })

  const tabIndex = ref(0)

  const devices = computed(() => {
    // idx 0: All
    switch(tabIndex.value) {
      case 0:
        return Object.keys(byDevice.value).map(mac => ({ mac })) // all
        // break
      default:
        return collections.value[tabIndex.value - 1]
        // break
    }
  })

  return {
    collections,
    tabIndex,
    devices
  }
}

// @vue/component
export default {
  name: 'base-data-flows',
  components,
  setup
}
</script>