/**
* "$_interfaces" store module
*/
import Vue from 'vue'
import { computed } from '@vue/composition-api'
import api from './_api'
import { columns as columnsInterface } from './config'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_interfaces/isLoading']),
    getList: () => $store.dispatch('$_interfaces/all'),
    createItem: params => $store.dispatch('$_interfaces/createInterface', params),
    getItem: params => $store.dispatch('$_interfaces/getInterface', params.id).then(item => {
      return (params.isClone)
        ? { ...item, id: item.master, not_deletable: false }
        : item
    }),
    updateItem: params => $store.dispatch('$_interfaces/updateInterface', params),
    deleteItem: params => $store.dispatch('$_interfaces/deleteInterface', params.id),
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
    interfaces: []
  }
}

const getters = {
  isWaiting: state => [types.LOADING, types.DELETING].includes(state.status),
  isLoading: state => state.status === types.LOADING,
  cacheFlattened: state => Object.values(state.cache),
  interfaces: state => state.interfaces
}

const actions = {
  all: ({ commit, getters }) => {
    const params = {
      sort: 'id',
      fields: columnsInterface.map(r => r.key).join(','),
      limit: 1000
    }
    commit('INTERFACE_REQUEST')
    return api.interfaces(params).then(response => {
      commit('INTERFACE_SUCCESS')
      commit('INTERFACES_REPLACED', response.items)
      response.items.forEach(item => {
        const { id } = item
        commit('INTERFACE_REPLACED', { ...item, id })
      })
      return getters.cacheFlattened
    }).catch((err) => {
      commit('INTERFACE_ERROR', err.response)
      throw err
    })
  },
  getInterface: ({ state, commit }, id) => {
    commit('INTERFACE_REQUEST')
    return api.interface(id).then(item => {
      commit('INTERFACE_REPLACED', { ...item, id })
      return state.cache[id]
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
  downInterface: ({ commit, dispatch }, id) => {
    commit('INTERFACE_REQUEST')
    return api.downInterface(id).then(response => {
      commit('INTERFACE_DOWN', id)
      dispatch('all')
      return response
    }).catch((err) => {
      commit('INTERFACE_ERROR', err.response)
      throw err
    })
  },
  upInterface: ({ commit, dispatch }, id) => {
    commit('INTERFACE_REQUEST')
    return api.upInterface(id).then(response => {
      commit('INTERFACE_UP', id)
      dispatch('all')
      return response
    }).catch((err) => {
      commit('INTERFACE_ERROR', err.response)
      throw err
    })
  },
  deleteInterface: ({ commit }, id) => {
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
  INTERFACES_REPLACED: (state, interfaces) => {
    state.interfaces = interfaces
  },
  INTERFACE_REQUEST: (state, type) => {
    state.status = type || types.LOADING
    state.message = ''
  },
  INTERFACE_REPLACED: (state, data) => {
    state.status = types.SUCCESS
    Vue.set(state.cache, data.id, data)
    const i = state.interfaces.findIndex(i => {
      return i.id == data.id
    })
    if (i >= 0) {
      Vue.set(state.interfaces[i], 'type', data.type)
    }
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
    if (!(id in state.cache))
      Vue.set(state.cache, id, {})
    Vue.set(state.cache[id], 'is_running', false)
  },
  INTERFACE_UP: (state, id) => {
    state.status = types.SUCCESS
    if (!(id in state.cache))
      Vue.set(state.cache, id, {})
    Vue.set(state.cache[id], 'is_running', true)
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
