/**
* "$_interfaces" store module
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
  cache: {},
  message: '',
  status: ''
}

const getters = {
  isWaiting: state => [types.LOADING, types.DELETING].includes(state.status),
  isLoading: state => state.status === types.LOADING
}

const actions = {
  all: ({ state, commit }) => {
    if (Object.keys(state.cache).length > 0) {
      return Promise.resolve(state.cache)
    }
    commit('INTERFACE_REQUEST')
    return api.interfaces().then(response => {
      commit('INTERFACES_REPLACED', response)
      return response
    }).catch((err) => {
      commit('INTERFACE_ERROR', err.response)
      throw err
    })
  },
  getInterface: ({ state, commit }, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id])
    }
    commit('INTERFACE_REQUEST')
    return api.interface(id).then(item => {
      commit('INTERFACE_REPLACED', { ...item, id })
      return item
    }).catch((err) => {
      commit('INTERFACE_ERROR', err.response)
      throw err
    })
  },
  createInterface: ({ commit }, data) => {
    commit('INTERFACE_REQUEST')
    return api.createInterface(data).then(response => {
      commit('INTERFACE_REPLACED', data)
      return response
    }).catch(err => {
      commit('INTERFACE_ERROR', err.response)
      throw err
    })
  },
  updateInterface: ({ commit }, data) => {
    commit('INTERFACE_REQUEST')
    return api.updateInterface(data).then(response => {
      commit('INTERFACE_REPLACED', data)
      return response
    }).catch(err => {
      commit('INTERFACE_ERROR', err.response)
      throw err
    })
  },
  downInterface: ({ state, commit }, id) => {
    commit('INTERFACE_REQUEST')
    return api.downInterface(id).then(response => {
      commit('INTERFACE_DOWN', id)
      return response
    }).catch((err) => {
      commit('INTERFACE_ERROR', err.response)
      throw err
    })
  },
  upInterface: ({ state, commit }, id) => {
    commit('INTERFACE_REQUEST')
    return api.upInterface(id).then(response => {
      commit('INTERFACE_UP', id)
      return response
    }).catch((err) => {
      commit('INTERFACE_ERROR', err.response)
      throw err
    })
  },
  deleteInterface: ({ state, commit }, id) => {
    commit('INTERFACE_REQUEST')
    return api.deleteInterface(id).then(response => {
      commit('INTERFACE_DESTROYED', id)
      return response
    }).catch((err) => {
      commit('INTERFACE_ERROR', err.response)
      throw err
    })
  }

}

const mutations = {
  INTERFACE_REQUEST: (state, type) => {
    state.status = type || types.LOADING
    state.message = ''
  },
  INTERFACES_REPLACED: (state, data) => {
    state.status = types.SUCCESS
    Vue.set(state, 'cache', data)
  },
  INTERFACE_REPLACED: (state, data) => {
    state.status = types.SUCCESS
    Vue.set(state.cache, data.id, data)
  },
  INTERFACE_DESTROYED: (state, id) => {
    state.status = types.SUCCESS
    Vue.set(state.cache, id, null)
  },
  INTERFACE_ERROR: (state, response) => {
    state.status = types.ERROR
    if (response && response.data) {
      state.message = response.data.message
    }
  },
  INTERFACE_SUCCESS: (state) => {
    state.status = types.SUCCESS
  },
  INTERFACE_DOWN: (state, id) => {
    state.status = types.SUCCESS
    Vue.set(state.cache, 'is_running', false)
  },
  INTERFACE_UP: (state, id) => {
    state.status = types.SUCCESS
    Vue.set(state.cache, 'is_running', true)
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
