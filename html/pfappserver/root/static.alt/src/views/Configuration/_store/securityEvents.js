/**
* "$_security_events" store module
*/
import Vue from 'vue'
import api from '../_api'

const types = {
  LOADING: 'loading',
  DELETING: 'deleting',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
const state = {
  cache: {}, // items details
  message: '',
  itemStatus: ''
}

const getters = {
  isWaiting: state => [types.LOADING, types.DELETING].includes(state.itemStatus),
  isLoading: state => state.itemStatus === types.LOADING
}

const actions = {
  all: () => {
    const params = {
      sort: 'id',
      fields: ['id'].join(',')
    }
    return api.securityEvents(params).then(response => {
      return response.items
    })
  },
  options: ({ commit }, id) => {
    commit('ITEM_REQUEST')
    if (id) {
      return api.securityEventOptions(id).then(response => {
        commit('ITEM_SUCCESS')
        return response
      }).catch((err) => {
        commit('ITEM_ERROR', err.response)
        throw err
      })
    } else {
      return api.securityEventsOptions().then(response => {
        commit('ITEM_SUCCESS')
        return response
      }).catch((err) => {
        commit('ITEM_ERROR', err.response)
        throw err
      })
    }
  },
  getSecurityEvent: ({ state, commit }, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id])
    }
    commit('ITEM_REQUEST')
    return api.securityEvent(id).then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  createSecurityEvent: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.createSecurityEvent(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateSecurityEvent: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.updateSecurityEvent(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  enableSecurityEvent: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    const _data = { id: data.id, enabled: 'Y' }
    return api.updateSecurityEvent(_data).then(response => {
      commit('ITEM_ENABLED', _data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  disableSecurityEvent: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    const _data = { id: data.id, enabled: 'N' }
    return api.updateSecurityEvent(_data).then(response => {
      commit('ITEM_DISABLED', _data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteSecurityEvent: ({ commit }, data) => {
    commit('ITEM_REQUEST', types.DELETING)
    return api.deleteSecurityEvent(data).then(response => {
      commit('ITEM_DESTROYED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  }
}

const mutations = {
  ITEM_REQUEST: (state, type) => {
    state.itemStatus = type || types.LOADING
    state.message = ''
  },
  ITEM_REPLACED: (state, data) => {
    state.itemStatus = types.SUCCESS
    Vue.set(state.cache, data.id, data)
  },
  ITEM_ENABLED: (state, data) => {
    state.itemStatus = types.SUCCESS
    Vue.set(state.cache, data.id, { ...state.cache[data.id], ...data })
  },
  ITEM_DISABLED: (state, data) => {
    state.itemStatus = types.SUCCESS
    Vue.set(state.cache, data.id, { ...state.cache[data.id], ...data })
  },
  ITEM_DESTROYED: (state, id) => {
    state.itemStatus = types.SUCCESS
    Vue.set(state.cache, id, null)
  },
  ITEM_ERROR: (state, response) => {
    state.itemStatus = types.ERROR
    if (response && response.data) {
      state.message = response.data.message
    }
  },
  ITEM_SUCCESS: (state) => {
    state.itemStatus = types.SUCCESS
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
