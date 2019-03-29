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
  interfaces: {
    cache: {},
    message: '',
    status: ''
  },
  l2networks: {
    cache: {},
    message: '',
    status: ''
  }
}

const getters = {
  isInterfacesWaiting: state => [types.LOADING, types.DELETING].includes(state.interfaces.status),
  isInterfacesLoading: state => state.interfaces.status === types.LOADING,

  isL2networksWaiting: state => [types.LOADING, types.DELETING].includes(state.l2networks.status),
  isL2networksLoading: state => state.l2networks.status === types.LOADING,
}

const actions = {
  all: ({ state, commit }) => {
    if (Object.keys(state.interfaces.cache).length > 0) {
      return Promise.resolve(state.interfaces.cache)
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
    if (state.interfaces.cache[id]) {
      return Promise.resolve(state.interfaces.cache[id])
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
    state.interfaces.status = type || types.LOADING
    state.interfaces.message = ''
  },
  INTERFACES_REPLACED: (state, data) => {
    state.interfaces.status = types.SUCCESS
    Vue.set(state.interfaces, 'cache', data)
  },
  INTERFACE_REPLACED: (state, data) => {
    state.interfaces.status = types.SUCCESS
    Vue.set(state.interfaces.cache, data.id, data)
  },
  INTERFACE_DESTROYED: (state, id) => {
    state.interfaces.status = types.SUCCESS
    Vue.set(state.interfaces.cache, id, null)
  },
  INTERFACE_ERROR: (state, response) => {
    state.interfaces.status = types.ERROR
    if (response && response.data) {
      state.interfaces.message = response.data.message
    }
  },
  INTERFACE_SUCCESS: (state) => {
    state.interfaces.status = types.SUCCESS
  },
  INTERFACE_DOWN: (state, id) => {
    state.interfaces.status = types.SUCCESS
    Vue.set(state.interfaces.cache, 'is_running', false)
  },
  INTERFACE_UP: (state, id) => {
    state.interfaces.status = types.SUCCESS
    Vue.set(state.interfaces.cache, 'is_running', true)
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
