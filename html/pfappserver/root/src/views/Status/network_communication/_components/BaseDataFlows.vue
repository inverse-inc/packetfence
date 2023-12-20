<template>
  <b-card no-body>
    <b-card-header>
      <b-row align-v="center">
        <b-col cols="auto">
          <h5 class="mb-0 d-inline">{{ $i18n.t('Flows') }}</h5>
        </b-col>
        <b-col cols="auto" class="ml-auto animate-switch">
          <base-label>{{ $i18n.t('Animate') }}</base-label>
          <base-input-switch :value="animate"
                             :onChange="animateOnChange"

          />
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
            {{ device.mac }} <b-badge pill variant="primary" class="ml-1">{{
              device.count
            }}</b-badge>
          </span>
        </template>
      </b-tab>
      <base-data-flow
        :animate="animate"
        :devices="devices"
        @device="toggleDevice"/>
    </b-tabs>
  </b-card>
</template>
<script>
import BaseDataFlow from './BaseDataFlow'
import {OnChangeFormGroupSwitch, BaseLabel} from '@/components/new/'
import BaseInputSwitch from '@/components/new/BaseInputSwitch'
import {computed, ref, toRefs, watch} from '@vue/composition-api'
import usePreference from '@/composables/usePreference'

const components = {
  BaseDataFlow,
  OnChangeFormGroupSwitch,
  BaseInputSwitch,
  BaseLabel
}

const props = {
  device: {
    type: String
  }
}

const setup = (props, context) => {

  const {
    device
  } = toRefs(props)

  const {root: {$store} = {}} = context

  const byDevice = computed(() => $store.getters['$_fingerbank_communication/byDevice'])

  const collections = ref([])
  watch(byDevice, () => {
    collections.value = Object.entries(byDevice.value)
      .map(([mac, data]) => ({mac, ...data}))
      .sort((a, b) => a.mac.localeCompare(b.mac))
      .map(item => ([item]))
  }, {immediate: true})

  const tabIndex = ref(0)

  const devices = computed(() => {
    // idx 0: All
    switch (tabIndex.value) {
      case 0:
        return Object.keys(byDevice.value).map(mac => ({mac})) // all
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
    } else {
      // view all
      tabIndex.value = 0
    }
  }

  watch(device, () => toggleDevice(device.value), {immediate: true})

  const animate = usePreference('vizsec::settings', 'animate', false)
  const animateOnChange = (toggleValue) => {
    animate.value = toggleValue
  }

  return {
    collections,
    tabIndex,
    devices,
    toggleDevice,
    animate,
    animateOnChange,
  }
}

// @vue/component
export default {
  name: 'base-data-flows',
  components,
  props,
  setup
}
</script>
<style>
  .animate-switch {
    display: flex;
  }
</style>
