/**
* "$_switches" store module
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
      fields: ['id', 'description', 'class'].join(',')
    }
    return api.switches(params).then(response => {
      return response.items
    })
  },
  getSwitch: ({ state, commit }, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id])
    }
    commit('ITEM_REQUEST')
    return api.switche(id).then(item => {
      commit('ITEM_REPLACED', item)
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  createSwitch: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.createSwitch(data).then(response => {
      commit('ITEM_REPLACED', data)
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateSwitch: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.updateSwitch(data).then(response => {
      commit('ITEM_REPLACED', data)
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteSwitch: ({ commit }, data) => {
    commit('ITEM_REQUEST', types.DELETING)
    return api.deleteSwitch(data).then(response => {
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
