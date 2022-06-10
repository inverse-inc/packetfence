/**
* "$_network_threats" store module
*/
import { createDebouncer } from 'promised-debounce'
import api from '@/views/Nodes/_api'

// Default values
const state = () => {
  return {
    cache: {}, // communication details
    message: '',
    status: '',
    selectedCategories: [],
    selectedSecurityEvents: [],
  }
}

let debouncer

const getters = {
  isLoading: state => state.status === 'loading'
}

const actions = {
  get: ({ commit }, params) => {
    let { nodes } = params
    return new Promise((resolve, reject) => {
      if (!nodes.length) {
        resolve(false)
      }
      else {
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
      }
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
  toggleCategory: ({ state, commit }, category) => {
    return new Promise(resolve => {
      const i = state.selectedCategories.findIndex(selected => selected === category)
      if (i > -1) {
        commit('CATEGORY_DESELECT', category)
        resolve(false)
      }
      else {
        // select category
        commit('CATEGORY_SELECT', category)
        resolve(true)
      }
    })
  },
  deselectCategories: ({ state, commit }, categories = []) => {
    return new Promise(resolve => {
      categories.forEach(category => {
        if (state.selectedCategories.indexOf(category) > -1) {
          commit('CATEGORY_DESELECT', category)
        }
      })
      resolve()
    })
  },
  selectCategories: ({ state, commit }, categories = []) => {
    return new Promise(resolve => {
      categories.forEach(category => {
        if (state.selectedCategories.indexOf(category) === -1) {
          commit('CATEGORY_SELECT', category)
        }
      })
      resolve()
    })
  },
  invertCategories: ({ state, commit }, categories = []) => {
    return new Promise(resolve => {
      categories.forEach(category => {
        if (state.selectedCategories.indexOf(category) === -1) {
          commit('CATEGORY_SELECT', category)
        }
        else {
          commit('CATEGORY_DESELECT', category)
        }
      })
      resolve()
    })
  },
  toggleSecurityEvent: ({ state, commit }, securityEvent) => {
    return new Promise(resolve => {
      const i = state.selectedSecurityEvents.findIndex(selected => selected === securityEvent)
      if (i > -1) {
        commit('SECURITY_EVENT_DESELECT', securityEvent)
        resolve(false)
      }
      else {
        commit('SECURITY_EVENT_SELECT', securityEvent)
        resolve(true)
      }
    })
  },
  deselectSecurityEvents: ({ state, commit }, securityEvents = []) => {
    return new Promise(resolve => {
      securityEvents.forEach(securityEvent => {
        if (state.selectedSecurityEvents.indexOf(securityEvent) > -1) {
          commit('SECURITY_EVENT_DESELECT', securityEvent)
        }
      })
      resolve()
    })
  },
  selectSecurityEvents: ({ state, commit }, securityEvents = []) => {
    return new Promise(resolve => {
      securityEvents.forEach(securityEvent => {
        if (state.selectedSecurityEvents.indexOf(securityEvent) === -1) {
          commit('SECURITY_EVENT_SELECT', securityEvent)
        }
      })
      resolve()
    })
  },
  invertSecurityEvents: ({ state, commit }, securityEvents = []) => {
    return new Promise(resolve => {
      securityEvents.forEach(securityEvent => {
        if (state.selectedSecurityEvents.indexOf(securityEvent) === -1) {
          commit('SECURITY_EVENT_SELECT', securityEvent)
        }
        else {
          commit('SECURITY_EVENT_DESELECT', securityEvent)
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
    state.cache = Object.entries(response).reduce((items, [category, data]) => {
      const { all_hosts_cache = {} } = data
      if (Object.values(all_hosts_cache).length > 0) {
        items[category] = data
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
  CATEGORY_DESELECT: (state, category) => {
    state.selectedCategories = [ ...state.selectedCategories.filter(selected => selected !== category) ]
  },
  CATEGORY_SELECT: (state, category) => {
    state.selectedCategories.push(category)
  },
  SECURITY_EVENT_DESELECT: (state, securityEvent) => {
    state.selectedSecurityEvents = [ ...state.selectedSecurityEvents.filter(selected => selected !== securityEvent) ]
  },
  SECURITY_EVENT_SELECT: (state, securityEvent) => {
    state.selectedSecurityEvents.push(securityEvent)
  },
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}