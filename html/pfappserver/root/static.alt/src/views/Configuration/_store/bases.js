/**
* "$_bases" store module
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
  all: ({ commit }) => {
    const params = {
      sort: 'id',
      fields: ['id'].join(',')
    }
    return api.bases(params).then(response => {
      response.items.forEach((item) => {
        commit('ITEM_REPLACED', item)
      })
      return response.items
    })
  },
  getBase: ({ state, commit }, id) => {
    if (state.cache[id]) {
      return Promise.resolve(state.cache[id])
    }
    commit('ITEM_REQUEST')
    return api.base(id).then(item => {
      if (id === 'general') {
        // build `fqdn` from `hostname` and `domain`
        item.fqdn = ((item.hostname) ? item.hostname + '.' : '') + item.domain
      }
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getGeneral: ({ state, commit }) => {
    if (state.cache['general']) {
      return Promise.resolve(state.cache['general'])
    }
    commit('ITEM_REQUEST')
    return api.base('general').then(item => {
      // build `fqdn` from `hostname` and `domain`
      item.fqdn = ((item.hostname) ? item.hostname + '.' : '') + item.domain
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getGuestsAdminRegistration: ({ state, commit }) => {
    if (state.cache['guests_admin_registration']) {
      return Promise.resolve(state.cache['guests_admin_registration'])
    }
    commit('ITEM_REQUEST')
    return api.base('guests_admin_registration').then(item => {
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  updateGuestsAdminRegistration: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    data.id = 'guests_admin_registration'
    return api.updateBase(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
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
