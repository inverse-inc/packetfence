/**
* "$_routed_networks" store module
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
    commit('ROUTED_NETWORK_REQUEST')
    return api.routedNetworks().then(response => {
      commit('ROUTED_NETWORK_SUCCESS')
      return response
    }).catch((err) => {
      commit('ROUTED_NETWORK_ERROR', err.response)
      throw err
    })
  },
  options: ({ commit }, id) => {
    commit('ROUTED_NETWORK_REQUEST')
    if (id) {
      return api.routedNetworkOptions(id).then(response => {
        commit('ROUTED_NETWORK_SUCCESS')
        return response
      }).catch((err) => {
        commit('ROUTED_NETWORK_ERROR', err.response)
        throw err
      })
    } else {
      return api.routedNetworksOptions().then(response => {
        commit('ROUTED_NETWORK_SUCCESS')
        return response
      }).catch((err) => {
        commit('ROUTED_NETWORK_ERROR', err.response)
        throw err
      })
    }
  },
  getRoutedNetwork: ({ state, commit }, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id])
    }
    commit('ROUTED_NETWORK_REQUEST')
    return api.routedNetwork(id).then(item => {
      commit('ROUTED_NETWORK_REPLACED', { ...item, id })
      return item
    }).catch((err) => {
      commit('ROUTED_NETWORK_ERROR', err.response)
      throw err
    })
  },
  createRoutedNetwork: ({ commit }, data) => {
    commit('ROUTED_NETWORK_REQUEST')
    return api.createRoutedNetwork(data).then(response => {
      commit('ROUTED_NETWORK_REPLACED', data)
      return response
    }).catch(err => {
      commit('ROUTED_NETWORK_ERROR', err.response)
      throw err
    })
  },
  updateRoutedNetwork: ({ commit }, data) => {
    commit('ROUTED_NETWORK_REQUEST')
    return api.updateRoutedNetwork(data).then(response => {
      commit('ROUTED_NETWORK_REPLACED', data)
      return response
    }).catch(err => {
      commit('ROUTED_NETWORK_ERROR', err.response)
      throw err
    })
  },
  deleteRoutedNetwork: ({ state, commit }, id) => {
    commit('ROUTED_NETWORK_REQUEST')
    return api.deleteRoutedNetwork(id).then(response => {
      commit('ROUTED_NETWORK_DESTROYED', id)
      return response
    }).catch((err) => {
      commit('ROUTED_NETWORK_ERROR', err.response)
      throw err
    })
  }

}

const mutations = {
  ROUTED_NETWORK_REQUEST: (state, type) => {
    state.status = type || types.LOADING
    state.message = ''
  },
  ROUTED_NETWORK_REPLACED: (state, data) => {
    state.status = types.SUCCESS
    Vue.set(state.cache, data.id, data)
  },
  ROUTED_NETWORK_DESTROYED: (state, id) => {
    state.status = types.SUCCESS
    Vue.set(state.cache, id, null)
  },
  ROUTED_NETWORK_ERROR: (state, response) => {
    state.status = types.ERROR
    if (response && response.data) {
      state.message = response.data.message
    }
  },
  ROUTED_NETWORK_SUCCESS: (state) => {
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
