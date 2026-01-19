<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ $t('Discover Network Devices') }}</h4>
    </b-card-header>
    <b-card-body>
      <p class="mb-3" v-t="'Scan your network using SNMP to discover switches and routers. Discovered devices can be added to your switch configuration.'"></p>

      <the-form
        :is-scanning="isScanning"
        :scan-status="currentScanStatus"
        @scan="onScan"
      />

      <b-progress
        v-if="isScanning && currentScanProgress < 100"
        :value="currentScanProgress"
        :max="100"
        class="mb-3"
        animated
        striped
      />

      <the-results
        :devices="devices"
        :is-loading="isScanning"
        @remove="onRemoveDevice"
        @clear="onClearDevices"
      />

      <b-alert
        v-if="snmpReport && snmpReport.length > 0"
        variant="warning"
        show
        class="mt-3"
      >
        <h5 class="alert-heading">{{ $t('SNMP Errors') }}</h5>
        <ul class="mb-0">
          <li v-for="(error, index) in snmpReport" :key="index">
            <code>{{ error.address }}</code>: {{ error.error }}
          </li>
        </ul>
      </b-alert>
    </b-card-body>
  </b-card>
</template>

<script>
import TheForm from './TheForm'
import TheResults from './TheResults'

const components = {
  TheForm,
  TheResults
}

import { computed, ref } from '@vue/composition-api'
import { useStore } from '../_store'

const setup = (props, context) => {
  const { root: { $store } = {} } = context

  const store = useStore($store)
  const {
    isScanning,
    devices,
    scans,
    snmpReport,
    discoverNetwork,
    removeDevice,
    clearDevices
  } = store

  const lastScannedNetwork = ref(null)

  const currentScanStatus = computed(() => {
    if (!lastScannedNetwork.value) return ''
    const scan = scans.value[lastScannedNetwork.value]
    return scan?.status || ''
  })

  const currentScanProgress = computed(() => {
    if (!lastScannedNetwork.value) return 0
    const scan = scans.value[lastScannedNetwork.value]
    return scan?.progress || 0
  })

  const onScan = (payload) => {
    lastScannedNetwork.value = payload.network
    discoverNetwork(payload)
  }

  const onRemoveDevice = (ip) => {
    removeDevice(ip)
  }

  const onClearDevices = () => {
    clearDevices()
  }

  return {
    isScanning,
    devices,
    snmpReport,
    currentScanStatus,
    currentScanProgress,
    onScan,
    onRemoveDevice,
    onClearDevices
  }
}

// @vue/component
export default {
  name: 'the-discover',
  inheritAttrs: false,
  components,
  setup
}
</script>
