/**
* "$_realms" store module
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
    return api.realms(params).then(response => {
      return response.items
    })
  },
  getRealm: ({ state, commit }, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id])
    }
    commit('ITEM_REQUEST')
    return api.realm(id).then(item => {
      commit('ITEM_REPLACED', item)
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  createRealm: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.createRealm(data).then(response => {
      commit('ITEM_REPLACED', data)
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateRealm: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.updateRealm(data).then(response => {
      commit('ITEM_REPLACED', data)
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteRealm: ({ commit }, data) => {
    commit('ITEM_REQUEST', types.DELETING)
    return api.deleteRealm(data).then(response => {
      commit('ITEM_DESTROYED', data)
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
  ITEM_DESTROYED: (state, id) => {
    state.itemStatus = types.SUCCESS
    Vue.set(state.cache, id, null)
  },
  ITEM_ERROR: (state, response) => {
    state.itemStatus = types.ERROR
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
