/**
* "$_roles" store module
*/
import Vue from 'vue'
import api from '../_api'

const types = {
  LOADING: 'loading',
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
  isLoading: state => state.itemStatus === types.LOADING
}

const actions = {
  getRole: ({state, commit}, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id])
    }
    commit('ITEM_REQUEST')
    return api.role(id).then(item => {
      commit('ITEM_REPLACED', item)
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
    })
  },
  updateRole: ({commit}, data) => {
    commit('ITEM_REQUEST')
    return api.updateRole(data).then(response => {
      commit('ITEM_REPLACED', data)
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
    })
  },
  deleteRole: ({commit}, data) => {
    commit('ITEM_REQUEST')
    return api.deleteRole(data).then(response => {
      commit('ITEM_DESTROYED', data)
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
    })
  }
}

const mutations = {
  ITEM_REQUEST: (state) => {
    state.itemStatus = types.LOADING
    state.message = ''
  },
  ITEM_REPLACED: (state, data) => {
    state.itemStatus = types.SUCCESS
    Vue.set(state.cache, data.id, data)
  },
  ITEM_DESTROYED: (state, id) => {
    state.itemStatus = 'success'
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
