<template>
  <b-card no-body>
    <b-card-header>
      <b-row align-v="center">
        <b-col cols="auto">
          <h5 class="mb-0 d-inline">{{ $i18n.t('Flows') }}</h5>
        </b-col>
        <b-col cols="auto" class="ml-auto">
          <base-input-toggle-false-true v-model="animate"
            :column-label="$i18n.t('Animate')"
            label-left :label-right="false"
            :options="[
            { value: false, label: $i18n.t('Animate') },
            { value: true, label: $i18n.t('Animate'), color: 'var(--primary)' }
          ]"/>
        </b-col>
      </b-row>
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
      <base-data-flow
        :animate="animate"
        :devices="devices"
        @device="toggleDevice" />
    </b-tabs>
  </b-card>
</template>
<script>
import BaseDataFlow from './BaseDataFlow'
import {
  BaseInputToggleFalseTrue
} from '@/components/new/'
const components = {
  BaseDataFlow,
  BaseInputToggleFalseTrue
}

import { computed, ref, watch } from '@vue/composition-api'
import usePreference from '@/composables/usePreference'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const byDevice = computed(() => $store.getters['$_fingerbank_communication/byDevice'])

  const collections = ref([])
  watch(byDevice, () => {
    collections.value = Object.entries(byDevice.value)
      .map(([mac, data]) => ({ mac, ...data }))
      .sort((a, b) => a.mac.localeCompare(b.mac))
      .map(item => ([ item ]))
  }, { immediate: true })

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

  const toggleDevice = mac => {
    if (tabIndex.value === 0) {
      // view specific device
      tabIndex.value = collections.value.findIndex(devices => devices.map(device => device.mac).indexOf(mac) > -1) + 1
    }
    else {
      // view all
      tabIndex.value = 0
    }
  }

  const animate = usePreference('vizsec::settings', 'animate', false)

  return {
    collections,
    tabIndex,
    devices,
    toggleDevice,
    animate
  }
}

// @vue/component
export default {
  name: 'base-data-flows',
  components,
  setup
}
</script>