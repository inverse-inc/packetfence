/**
* "$_fingerbank_communication" store module
*/
import { createDebouncer } from 'promised-debounce'
import api from '@/views/Nodes/_api'
import { decorateDevice, decorateProtocol, splitHost, splitProtocol } from './_composables/useCommunication'

// Default values
const state = () => {
  return {
    cache: {}, // communication details
    message: '',
    status: '',
    selectedDevices: [],
    selectedHosts: [],
    selectedProtocols: []
  }
}

let debouncer

const getters = {
  isLoading: state => state.status === 'loading',
  tabular: state => {
    const selectedHosts = state.selectedHosts
    const selectedProtocols = state.selectedProtocols
    return Object.entries(state.cache).reduce((tabular, [device, { all_hosts_cache = {} }]) => {
      const mac = decorateDevice(device)
      const hosts_cache = Object.entries(all_hosts_cache)
      for (let h = 0; h < hosts_cache.length; h++) {
        const [host, device_cache] = hosts_cache[h]
        const protocols = Object.entries(device_cache)
        for (let p = 0; p < protocols.length; p++) {
          const [_protocol, count] = protocols[p]
          const protocol = decorateProtocol(_protocol)
          if (
            (selectedHosts.length === 0 && selectedProtocols.length === 0)
            || (selectedHosts.length > 0 && selectedHosts.findIndex(selected => {
              return selected.toLowerCase() === host.toLowerCase() || RegExp(`.${selected}$`, 'i').test(host) || RegExp(`^${selected}:[0-9]{1,5}$`, 'i').test(host)
            }) > -1)
            || (selectedProtocols.length > 0 && selectedProtocols.findIndex(selected => {
              return selected.toLowerCase() === protocol.toLowerCase() || RegExp(`^${selected}:`, 'i').test(protocol)
            }) > -1)
          ) {
            tabular.push({ mac, device, host, protocol, count, ...splitHost(host), ...splitProtocol(protocol) })
          }
        }
      }
      return tabular
    }, [])
  },
  byDevice: (state, getters) => {
    return getters.tabular.reduce((devices, item) => {
      const { mac, host, protocol, count } = item
      if (!(mac in devices)) {
        devices[mac] = { hosts: {}, protocols: { }}
      }
      devices[mac]['count'] = (devices[mac]['count'] || 0) + count
      devices[mac]['hosts'][host] = (devices[mac]['hosts'][host] || 0) + count
      devices[mac]['protocols'][protocol] = (devices[mac]['protocols'][protocol] || 0) + count
      return devices
    }, {})
  }
}

const actions = {
  get: ({ commit }, params) => {
    let { nodes } = params
    return new Promise((resolve, reject) => {
      commit('REQUEST')
      api.fingerbankCommunications({
        nodes: nodes.map(mac => mac.replace(/[^0-9A-F]/gi, ''))
      }).then(response => {
        commit('RESPONSE', response)
        resolve(true)
      }).catch(err => {
        commit('ERROR', err)
        reject(err)
      })
    })
  },
  getDebounced: ({ dispatch }, params) => {
    if (!debouncer) {
      debouncer = createDebouncer()
    }
    debouncer({
      handler: () => dispatch('get', params),
      time: 100 // 100ms
    })
  },
  toggleDevice: ({ state, commit, dispatch }, device) => {
    return new Promise(resolve => {
      const i = state.selectedDevices.findIndex(selected => selected === device)
      if (i > -1) {
        commit('DEVICE_DESELECT', device)
        dispatch('getDebounced', { nodes: state.selectedDevices })
        resolve(false)
      }
      else {
        // select device
        commit('DEVICE_SELECT', device)
        dispatch('getDebounced', { nodes: state.selectedDevices })
        resolve(true)
      }
    })
  },
  deselectDevices: ({ state, commit, dispatch }, devices = []) => {
    return new Promise(resolve => {
      devices.forEach(device => {
        if (state.selectedDevices.indexOf(device) > -1) {
          commit('DEVICE_DESELECT', device)
          dispatch('getDebounced', { nodes: state.selectedDevices })
        }
      })
      resolve()
    })
  },
  selectDevices: ({ state, commit, dispatch }, devices = []) => {
    return new Promise(resolve => {
      devices.forEach(device => {
        if (state.selectedDevices.indexOf(device) === -1) {
          commit('DEVICE_SELECT', device)
          dispatch('getDebounced', { nodes: state.selectedDevices })
        }
      })
      resolve()
    })
  },
  invertDevices: ({ state, commit, dispatch }, devices = []) => {
    return new Promise(resolve => {
      devices.forEach(device => {
        if (state.selectedDevices.indexOf(device) === -1) {
          commit('DEVICE_SELECT', device)
          dispatch('getDebounced', { nodes: state.selectedDevices })
        }
        else {
          commit('DEVICE_DESELECT', device)
          dispatch('getDebounced', { nodes: state.selectedDevices })
        }
      })
      resolve()
    })
  },
  toggleHost: ({ state, commit }, host) => {
    return new Promise(resolve => {
      const i = state.selectedHosts.findIndex(selected => selected === host)
      if (i > -1) {
        commit('HOST_DESELECT', host)
        resolve(false)
      }
      else {
        // deselect all subdomains
        state.selectedHosts.forEach(selectedHost => {
          if (RegExp(`.${host}$`, 'i').test(selectedHost)) {
            commit('HOST_DESELECT', selectedHost)
          }
        })
        // select host
        commit('HOST_SELECT', host)
        resolve(true)
      }
    })
  },
  deselectHosts: ({ state, commit }, hosts = []) => {
    return new Promise(resolve => {
      hosts.forEach(host => {
        if (state.selectedHosts.indexOf(host) > -1) {
          commit('HOST_DESELECT', host)
        }
      })
      resolve()
    })
  },
  selectHosts: ({ state, commit }, hosts = []) => {
    return new Promise(resolve => {
      hosts.forEach(host => {
        if (state.selectedHosts.indexOf(host) === -1) {
          commit('HOST_SELECT', host)
        }
      })
      resolve()
    })
  },
  invertHosts: ({ state, commit }, hosts = []) => {
    return new Promise(resolve => {
      hosts.forEach(host => {
        if (state.selectedHosts.indexOf(host) === -1) {
          commit('HOST_SELECT', host)
        }
        else {
          commit('HOST_DESELECT', host)
        }
      })
      resolve()
    })
  },
  toggleProtocol: ({ state, commit }, protocol) => {
    return new Promise(resolve => {
      const i = state.selectedProtocols.findIndex(selected => selected === protocol)
      if (i > -1) {
        commit('PROTOCOL_DESELECT', protocol)
        resolve(false)
      }
      else {
        // deselect all subdomains
        state.selectedProtocols.forEach(selectedProtocol => {
          if (RegExp(`^${protocol}:`, 'i').test(selectedProtocol)) {
            commit('PROTOCOL_DESELECT', selectedProtocol)
          }
        })
        // select host
        commit('PROTOCOL_SELECT', protocol)
        resolve(true)
      }
    })
  },
  deselectProtocols: ({ state, commit }, protocols = []) => {
    return new Promise(resolve => {
      protocols.forEach(protocol => {
        if (state.selectedProtocols.indexOf(protocol) > -1) {
          commit('PROTOCOL_DESELECT', protocol)
        }
      })
      resolve()
    })
  },
  selectProtocols: ({ state, commit }, protocols = []) => {
    return new Promise(resolve => {
      protocols.forEach(protocol => {
        if (state.selectedProtocols.indexOf(protocol) === -1) {
          commit('PROTOCOL_SELECT', protocol)
        }
      })
      resolve()
    })
  },
  invertProtocols: ({ state, commit }, protocols = []) => {
    return new Promise(resolve => {
      protocols.forEach(protocol => {
        if (state.selectedProtocols.indexOf(protocol) === -1) {
          commit('PROTOCOL_SELECT', protocol)
        }
        else {
          commit('PROTOCOL_DESELECT', protocol)
        }
      })
      resolve()
    })
  },
}

const mutations = {
  REQUEST: (state) => {
    state.status = 'loading'
    state.message = ''
  },
  RESPONSE: (state, response) => {
    state.status = 'success'
    // skip empty
    state.cache = Object.entries(response).reduce((items, [device, data]) => {
      const { all_hosts_cache = {} } = data
      if (Object.values(all_hosts_cache).length > 0) {
        items[device] = data
      }
      return items
    }, {})
  },
  ERROR: (state, response) => {
    state.status = 'error'
    if (response && response.data) {
      state.message = response.data.message
    }
  },
  DEVICE_DESELECT: (state, device) => {
    state.selectedDevices = [ ...state.selectedDevices.filter(selected => selected !== device) ]
  },
  DEVICE_SELECT: (state, device) => {
    state.selectedDevices.push(device)
  },
  HOST_DESELECT: (state, host) => {
    state.selectedHosts = [ ...state.selectedHosts.filter(selected => selected !== host) ]
  },
  HOST_SELECT: (state, host) => {
    state.selectedHosts.push(host)
  },
  PROTOCOL_DESELECT: (state, protocol) => {
    state.selectedProtocols = [ ...state.selectedProtocols.filter(selected => selected !== protocol) ]
  },
  PROTOCOL_SELECT: (state, protocol) => {
    state.selectedProtocols.push(protocol)
  },
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
