/**
* "$_fingerbank_communication" store module
*/
import Vue from 'vue'
import { computed } from '@vue/composition-api'
import store from '@/store'
import i18n from '@/utils/locale'
import api from '@/views/Nodes/_api'

// Default values
const state = () => {
  return {
    cache: {}, // communcation details
    message: '',
    status: ''
  }
}

const getters = {
  isLoading: state => state.status === 'loading',
  hosts: state => {
    return Object.entries(state.cache).reduce((hosts, [device, value]) => {
      const { all_hosts_cache = {} } = value
      const hosts_cache = Object.entries(all_hosts_cache)
      for (let i = 0; i < hosts_cache.length; i++) {
        const [host, device_cache] = hosts_cache[i]
        if (host) {
          if (!(host in hosts)) {
            hosts[host] = { devices: {}, protocols: {} }
          }
          hosts[host]['devices'][device] = Object.values(device_cache).reduce((sum, value) => {
            return sum + value
          }, 0)
          const protocols = Object.entries(device_cache)
          for (let p = 0; p < protocols.length; p++) {
            const [protocol, count] = protocols[p]
            // early version does not include proto in 'proto:port'
            const [port, proto = 'UNKNOWN'] = protocol.split(':').reverse()
            const _protocol = `${proto.toUpperCase()}:${port}`
            hosts[host].protocols[_protocol] = (hosts[host].protocols[_protocol] || 0) + count
          }
        }
      }
      return hosts
    }, {})
  },
  protocols: state => {
    return Object.entries(state.cache).reduce((protocols, [device, value]) => {
      const { all_hosts_cache = {} } = value
      const hosts_cache = Object.entries(all_hosts_cache)
      for (let i = 0; i < hosts_cache.length; i++) {
        const [host, device_cache] = hosts_cache[i]
        const _protocols = Object.entries(device_cache)
        for (let p = 0; p < _protocols.length; p++) {
          const [protocol, count] = _protocols[p]
          // early version does not include proto in 'proto:port'
          const [port, proto = 'UNKNOWN'] = protocol.split(':').reverse()
          const _protocol = `${proto.toUpperCase()}:${port}`
          if (!(_protocol in protocols)) {
            protocols[_protocol] = { devices: { [device]: count }, hosts: { [host]: count } }
          }
          else {
            protocols[_protocol].devices[device] = (protocols[_protocol].devices[device] || 0) + count
            protocols[_protocol].hosts[host] = (protocols[_protocol].hosts[host] || 0) + count
          }
        }
      }
      return protocols
    }, {})
  },
}

const actions = {
  get: ({ state, commit }, params) => {
    return new Promise((resolve, reject) => {
      commit('REQUEST')
      api.fingerbankCommunications(params).then(response => {
        commit('RESPONSE', response)
        resolve(true)
      }).catch(err => {
        commit('ERROR', err)
        reject(err)
      })
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
    state.cache = {
      ...state.cache,
      ...response
    }
  },
  ERROR: (state, response) => {
    state.status = 'error'
    if (response && response.data) {
      state.message = response.data.message
    }
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
