import Vue from 'vue'
import store from '@/store'
import api from './_api'

const types = {
  LOADING: 'loading',
  DELETING: 'deleting',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
export const state = () => {
  return {
    caListCache: false, // ca list details
    caItemCache: {}, // ca item details
    caMessage: '',
    caStatus: ''
  }
}

export const getters = {
  isCaWaiting: state => [types.LOADING, types.DELETING].includes(state.caStatus),
  isCaLoading: state => state.caStatus === types.LOADING,
  cas: state => state.caListCache
}

export const actions = {
  allCas: ({ state, commit }) => {
    if (state.caListCache) {
      return Promise.resolve(state.caListCache)
    }
    commit('CA_REQUEST')
    return api.list().then(response => {
      commit('CA_LIST_REPLACED', response.items)
      return state.caListCache
    }).catch((err) => {
      commit('CA_ERROR', err.response)
      throw err
    })
  },
  getCa: ({ state, commit }, id) => {
    if (state.caItemCache[id]) {
      return Promise.resolve(state.caItemCache[id])
    }
    commit('CA_REQUEST')
    return api.item(id).then(item => {
      commit('CA_ITEM_REPLACED', item)
      return state.caItemCache[id]
    }).catch((err) => {
      commit('CA_ERROR', err.response)
      throw err
    })
  },
  createCa: ({ commit, dispatch }, data) => {
    commit('CA_REQUEST')
    return api.create(data).then(item => {
      // reset list
      commit('CA_LIST_RESET')
      dispatch('allCas')
      // update item
      commit('CA_ITEM_REPLACED', item)
      return item
    }).catch(err => {
      commit('CA_ERROR', err.response)
      throw err
    })
  }
}

export const mutations = {
  CA_REQUEST: (state, type) => {
    state.caStatus = type || types.LOADING
    state.caMessage = ''
  },
  CA_LIST_RESET: (state) => {
    state.caListCache = false
  },
  CA_LIST_REPLACED: (state, items) => {
    state.caStatus = types.SUCCESS
    state.caListCache = items
  },
  CA_ITEM_REPLACED: (state, data) => {
    state.caStatus = types.SUCCESS
    Vue.set(state.caItemCache, data.ID, data)
    store.dispatch('config/resetPkiCas')
  },
  CA_ERROR: (state, response) => {
    state.caStatus = types.ERROR
    if (response && response.data) {
      state.caMessage = response.data.message
    }
  }
}
