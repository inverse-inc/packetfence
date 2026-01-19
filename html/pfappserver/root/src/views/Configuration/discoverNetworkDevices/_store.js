/**
* "$_discover_network_devices" store module
*/
import Vue from 'vue'
import { computed } from '@vue/composition-api'
import { types } from '@/store'
import api from './_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_discover_network_devices/isLoading']),
    isScanning: computed(() => $store.getters['$_discover_network_devices/isScanning']),
    devices: computed(() => $store.getters['$_discover_network_devices/devices']),
    scans: computed(() => $store.state.$_discover_network_devices.scans),
    modules: computed(() => $store.state.$_discover_network_devices.modules),
    snmpReport: computed(() => $store.state.$_discover_network_devices.snmpReport),
    scanProgress: network => computed(() => {
      const scan = $store.state.$_discover_network_devices.scans[network]
      return scan?.progress || 0
    }),
    discoverNetwork: params => $store.dispatch('$_discover_network_devices/discoverNetwork', params),
    removeDevice: ip => $store.dispatch('$_discover_network_devices/removeDevice', ip),
    clearDevices: () => $store.dispatch('$_discover_network_devices/clearDevices'),
    clearDevicesFromNetwork: network => $store.dispatch('$_discover_network_devices/clearDevicesFromNetwork', network)
  }
}

// Default values
const state = () => {
  return {
    // Persisted data
    cache: {},              // { [ip]: { ...device, network, discoveredAt } }
    modules: [],            // Switch modules from API
    snmpReport: [],         // Errors from scan

    // Background scan tracking (per-network)
    scans: {},              // { [network]: { task_id, status, progress, error, startedAt } }

    // Global status
    message: '',
    itemStatus: ''
  }
}

const getters = {
  isWaiting: state => [types.LOADING].includes(state.itemStatus),
  isLoading: state => state.itemStatus === types.LOADING,
  isScanning: state => Object.values(state.scans).some(s => s.status === types.LOADING),
  devices: state => Object.values(state.cache).sort((a, b) => {
    // Sort by IP address numerically
    const aNum = a.ip.split('.').map(n => parseInt(n, 10).toString().padStart(3, '0')).join('')
    const bNum = b.ip.split('.').map(n => parseInt(n, 10).toString().padStart(3, '0')).join('')
    return aNum.localeCompare(bNum)
  }),
  scanStatus: state => network => state.scans[network]?.status || ''
}

const actions = {
  discoverNetwork: ({ commit, dispatch }, { network, addresses, credentials, options }) => {
    commit('SCAN_REQUEST', network)
    return api.discover({ addresses, credentials, options }).then(response => {
      const { task_id } = response
      // Task forked - track it and start polling
      commit('SCAN_POLLING', { network, task_id })
      // Poll in background - don't block
      dispatch('pollScanResults', { network, task_id })
      return { task_id }
    }).catch(err => {
      commit('SCAN_ERROR', { network, error: err.response || err })
      throw err
    })
  },

  pollScanResults: ({ commit, dispatch }, { network, task_id }) => {
    return api.pollTaskStatus({ task_id }).then(data => {
      // Check if task is still in progress (status 202)
      if ('status' in data && data.status.toString() === '202') {
        // Update progress if available
        if (data.progress !== undefined) {
          commit('SCAN_PROGRESS', { network, progress: data.progress })
        }
        // Continue polling
        return dispatch('pollScanResults', { network, task_id })
      }
      // Task complete - check for errors
      if ('error' in data) {
        throw new Error(data.error.message)
      }
      // Success - process results
      commit('SCAN_SUCCESS', { network, response: data.item })
      return data.item
    }).catch(err => {
      commit('SCAN_ERROR', { network, error: err.response || err })
      throw err
    })
  },

  removeDevice: ({ commit }, ip) => {
    commit('DEVICE_DESTROYED', ip)
  },

  clearDevices: ({ commit }) => {
    commit('DEVICES_CLEARED')
  },

  clearDevicesFromNetwork: ({ commit }, network) => {
    commit('DEVICES_CLEARED_FROM_NETWORK', network)
  }
}

const mutations = {
  SCAN_REQUEST: (state, network) => {
    state.itemStatus = types.LOADING
    state.message = ''
    Vue.set(state.scans, network, {
      status: types.LOADING,
      task_id: null,
      progress: 0,
      error: null,
      startedAt: Date.now()
    })
  },

  SCAN_POLLING: (state, { network, task_id }) => {
    Vue.set(state.scans, network, {
      ...state.scans[network],
      status: types.LOADING,
      task_id,
      progress: 0
    })
  },

  SCAN_PROGRESS: (state, { network, progress }) => {
    if (state.scans[network]) {
      Vue.set(state.scans, network, {
        ...state.scans[network],
        progress: Math.min(99, progress) // Cap at 99 until complete
      })
    }
  },

  SCAN_SUCCESS: (state, { network, response }) => {
    const { modules = [], scan: { devices = [], snmp_report = [] } = {} } = response

    // Remove existing devices from this network only (merge logic)
    Object.keys(state.cache).forEach(ip => {
      if (state.cache[ip].network === network) {
        Vue.delete(state.cache, ip)
      }
    })

    // Add new devices keyed by IP
    devices.forEach(device => {
      Vue.set(state.cache, device.ip, {
        ...device,
        network,
        discoveredAt: Date.now()
      })
    })

    state.modules = modules
    state.snmpReport = snmp_report
    state.itemStatus = types.SUCCESS
    state.message = ''
    Vue.set(state.scans, network, {
      ...state.scans[network],
      status: types.SUCCESS,
      progress: 100
    })
  },

  SCAN_ERROR: (state, { network, error }) => {
    state.itemStatus = types.ERROR
    if (error && error.data) {
      state.message = error.data.message
    }
    Vue.set(state.scans, network, {
      ...state.scans[network],
      status: types.ERROR,
      error: error?.data?.message || error?.message || error
    })
  },

  DEVICE_DESTROYED: (state, ip) => {
    Vue.delete(state.cache, ip)
  },

  DEVICES_CLEARED: (state) => {
    state.cache = {}
    state.snmpReport = []
  },

  DEVICES_CLEARED_FROM_NETWORK: (state, network) => {
    Object.keys(state.cache).forEach(ip => {
      if (state.cache[ip].network === network) {
        Vue.delete(state.cache, ip)
      }
    })
  },

  $RESET: (state) => {
    // Reset scan state but preserve discovered devices
    state.scans = {}
    state.itemStatus = ''
    state.message = ''
    // NOTE: cache, modules NOT reset - intentional for persistence
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
