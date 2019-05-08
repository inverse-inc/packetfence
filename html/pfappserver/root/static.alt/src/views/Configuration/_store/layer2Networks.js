/**
* "$_layer2_networks" store module
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
    commit('LAYER2_NETWORK_REQUEST')
    return api.layer2Networks().then(response => {
      commit('LAYER2_NETWORK_SUCCESS')
      return response
    }).catch((err) => {
      commit('LAYER2_NETWORK_ERROR', err.response)
      throw err
    })
  },
  options: ({ commit }, id) => {
    commit('LAYER2_NETWORK_REQUEST')
    if (id) {
      return api.layer2NetworkOptions(id).then(response => {
        commit('LAYER2_NETWORK_SUCCESS')
        return response
      }).catch((err) => {
        commit('LAYER2_NETWORK_ERROR', err.response)
        throw err
      })
    } else {
      return api.layer2NetworksOptions().then(response => {
        commit('LAYER2_NETWORK_SUCCESS')
        return response
      }).catch((err) => {
        commit('LAYER2_NETWORK_ERROR', err.response)
        throw err
      })
    }
  },
  getLayer2Network: ({ state, commit }, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id]).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('LAYER2_NETWORK_REQUEST')
    return api.layer2Network(id).then(item => {
      commit('LAYER2_NETWORK_REPLACED', { ...item, id })
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('LAYER2_NETWORK_ERROR', err.response)
      throw err
    })
  },
  updateLayer2Network: ({ commit }, data) => {
    commit('LAYER2_NETWORK_REQUEST')
    return api.updateLayer2Network(data).then(response => {
      commit('LAYER2_NETWORK_REPLACED', data)
      return response
    }).catch(err => {
      commit('LAYER2_NETWORK_ERROR', err.response)
      throw err
    })
  }
}

const mutations = {
  LAYER2_NETWORK_REQUEST: (state, type) => {
    state.status = type || types.LOADING
    state.message = ''
  },
  LAYER2_NETWORK_REPLACED: (state, data) => {
    state.status = types.SUCCESS
    Vue.set(state.cache, data.id, JSON.parse(JSON.stringify(data)))
  },
  LAYER2_NETWORK_DESTROYED: (state, id) => {
    state.status = types.SUCCESS
    Vue.set(state.cache, id, null)
  },
  LAYER2_NETWORK_ERROR: (state, response) => {
    state.status = types.ERROR
    if (response && response.data) {
      state.message = response.data.message
    }
  },
  LAYER2_NETWORK_SUCCESS: (state) => {
    state.status = types.SUCCESS
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
