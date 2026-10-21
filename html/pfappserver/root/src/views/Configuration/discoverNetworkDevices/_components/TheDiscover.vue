<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ $t('Discover Network Devices') }}</h4>
    </b-card-header>
    <b-card-body>
      <p class="mb-3" v-t="'Scan your network using SNMP to discover switches and routers. Discovered devices can be added to your switch configuration.'"></p>

      <the-form
        :is-scanning="isScanning"
        @scan="onScan"
      />

      <b-alert
        v-if="isScanning"
        variant="info"
        show
        class="mt-3"
      >
        <h5 class="alert-heading">{{ $t('Scanning {network}...', { network: scanningNetwork }) }}</h5>
        <b-progress
          :value="currentScanProgress"
          :max="100"
          class="mb-3"
          animated
          striped
        />
        <b-button
          variant="outline-danger"
          size="sm"
          @click="onCancelScan"
        >{{ $t('Cancel Scan') }}</b-button>
      </b-alert>

      <b-tabs class="mt-3" content-class="mt-3">
        <b-tab active>
          <template #title>
            {{ $t('Devices') }}
            <b-badge pill variant="danger" class="ml-1">{{ devices.length }}</b-badge>
          </template>
          <the-results
            :devices="devices"
            :switch-ids="switchIds"
            :switch-types="switchTypes"
            :is-loading="isScanning"
            @view-switch="onViewSwitch"
            @create-switch="onCreateSwitch"
            @remove="onRemoveDevice"
            @clear="onClearDevices"
          />
        </b-tab>
        <b-tab>
          <template #title>
            {{ $t('Errors') }}
            <b-badge pill variant="danger" class="ml-1">{{ snmpErrors.length }}</b-badge>
          </template>
          <b-table
            :items="snmpErrors"
            :fields="errorFields"
            :busy="isScanning"
            class="mb-0"
            show-empty
            striped
            hover
          >
            <template #empty>
              <div class="text-center text-muted py-5">
                <icon name="check-circle" scale="3" class="mb-3" />
                <p class="mb-0">{{ $t('No errors encountered during scan.') }}</p>
              </div>
            </template>
            <template #cell(network)="{ value }">
              <code v-if="value">{{ value }}</code>
              <span v-else class="text-muted">-</span>
            </template>
            <template #cell(address)="{ value }">
              <code>{{ value }}</code>
            </template>
            <template #cell(message)="{ value }">
              <span class="text-danger">{{ value }}</span>
            </template>
          </b-table>
        </b-tab>
      </b-tabs>
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

import { computed, onMounted, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { useStore } from '../_store'

// Map discover credential type to switch SNMPVersion format
const snmpVersionMap = {
  'snmp_v1': '1',
  'snmp_v2c': '2c',
  'snmp_v3': '3'
}

const setup = (props, context) => {
  const { root: { $router, $store } = {} } = context

  const store = useStore($store)
  const {
    isScanning,
    devices,
    scans,
    snmpErrors,
    discoverNetwork,
    cancelScan,
    removeDevice,
    clearDevices
  } = store

  const switchIds = ref([])
  const switchTypes = ref([]) // All available switch types from OPTIONS

  // Derive scanning network from store state (persists across navigation)
  const scanningNetwork = computed(() => {
    const scanEntries = Object.entries(scans.value || {})
    const active = scanEntries.find(([, scan]) => scan.status === 'loading')
    return active ? active[0] : null
  })

  const currentScanProgress = computed(() => {
    if (!scanningNetwork.value) return 0
    const scan = scans.value[scanningNetwork.value]
    return scan?.progress || 0
  })

  const fetchSwitches = () => {
    $store.dispatch('$_switches/all').then(switches => {
      switchIds.value = switches.map(s => s.id)
    }).catch(() => {
      switchIds.value = []
    })
  }

  const fetchSwitchTypes = () => {
    $store.dispatch('$_switches/optionsBySwitchGroup', 'default').then(options => {
      const { meta: { type: { allowed: switchGroups = [] } = {} } = {} } = options
      // Extract all switch type values from grouped options
      const types = []
      switchGroups.forEach(group => {
        const { options: groupOptions = [] } = group
        groupOptions.forEach(opt => {
          if (opt.value) {
            types.push(opt.value)
          }
        })
      })
      switchTypes.value = types
    }).catch(() => {
      switchTypes.value = []
    })
  }

  onMounted(() => {
    fetchSwitches()
    fetchSwitchTypes()
  })

  const onScan = (payload) => {
    discoverNetwork(payload)
  }

  const onViewSwitch = (id) => {
    $router.push({ name: 'switch', params: { id } })
  }

  const onCreateSwitch = (device) => {
    const { ip, network, credential = {}, type } = device
    const query = {
      id: ip,
      network,
      SNMPVersion: snmpVersionMap[credential.type] || '',
      type: type || ''
    }
    $router.push({ name: 'newSwitch', params: { switchGroup: 'default' }, query })
  }

  const onRemoveDevice = (ip) => {
    removeDevice(ip)
  }

  const onClearDevices = () => {
    clearDevices()
  }

  const onCancelScan = () => {
    if (scanningNetwork.value) {
      cancelScan(scanningNetwork.value)
    }
  }

  const errorFields = [
    {
      key: 'network',
      label: i18n.t('Network'),
      sortable: true
    },
    {
      key: 'address',
      label: i18n.t('IP Address'),
      sortable: true
    },
    {
      key: 'message',
      label: i18n.t('Error'),
      sortable: true
    }
  ]

  return {
    isScanning,
    devices,
    switchIds,
    switchTypes,
    snmpErrors,
    errorFields,
    scanningNetwork,
    currentScanProgress,
    onScan,
    onViewSwitch,
    onCreateSwitch,
    onRemoveDevice,
    onClearDevices,
    onCancelScan
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
