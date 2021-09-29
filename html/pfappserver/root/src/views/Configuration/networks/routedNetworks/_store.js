/**
* "$_routed_networks" store module
*/
import Vue from 'vue'
import { computed } from '@vue/composition-api'
import api from './_api'
import { columns as columnsRoutedNetwork } from './config'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_routed_networks/isLoading']),
    getList: () => $store.dispatch('$_routed_networks/all'),
    getListOptions: () => $store.dispatch('$_routed_networks/options'),
    createItem: params => $store.dispatch('$_routed_networks/createRoutedNetwork', params),
    getItem: params => $store.dispatch('$_routed_networks/getRoutedNetwork', params.id),
    getItemOptions: params => $store.dispatch('$_routed_networks/options', params.id),
    updateItem: params => $store.dispatch('$_routed_networks/updateRoutedNetwork', params),
    deleteItem: params => $store.dispatch('$_routed_networks/deleteRoutedNetwork', params.id)
  }
}

const types = {
  LOADING: 'loading',
  DELETING: 'deleting',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
const state = () => {
  return {
    cache: {},
    message: '',
    status: '',
    routedNetworks: []
  }
}

const getters = {
  isWaiting: state => [types.LOADING, types.DELETING].includes(state.status),
  isLoading: state => state.status === types.LOADING,
  routedNetworks: state => state.routedNetworks
}

const actions = {
  all: ({ commit }) => {
    const params = {
      sort: 'id',
      fields: columnsRoutedNetwork.map(r => r.key).join(','),
      limit: 1000
    }
    commit('ROUTED_NETWORK_REQUEST')
    return api.routedNetworks(params).then(response => {
      commit('ROUTED_NETWORK_SUCCESS')
      commit('ROUTED_NETWORKS_REPLACED', response.items)
      return response.items
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
      return state.cache[id]
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
  deleteRoutedNetwork: ({ commit }, id) => {
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
  ROUTED_NETWORKS_REPLACED: (state, routedNetworks) => {
    state.routedNetworks = routedNetworks
  },
  ROUTED_NETWORK_REQUEST: (state, type) => {
    state.status = type || types.LOADING
    state.message = ''
  },
  ROUTED_NETWORK_REPLACED: (state, data) => {
    state.status = types.SUCCESS
    Vue.set(state.cache, data.id, data)
    const i = state.routedNetworks.findIndex(i => {
      return i.id == data.id
    })
    if (i >= 0) {
      Vue.set(state.routedNetworks, i, data)
    }
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
