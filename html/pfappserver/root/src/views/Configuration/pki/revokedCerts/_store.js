import Vue from 'vue'
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
    revokedCertListCache: false, // revoked cert list details
    revokedCertItemCache: {}, // revoked cert item details
    revokedCertMessage: '',
    revokedCertStatus: ''
  }
}

export const getters = {
  isRevokedCertWaiting: state => [types.LOADING, types.DELETING].includes(state.revokedCertStatus),
  isRevokedCertLoading: state => state.revokedCertStatus === types.LOADING,
  revokedCerts: state => state.revokedCertListCache
}

export const actions = {
  allRevokedCerts: ({ state, commit }) => {
    if (state.revokedCertListCache) {
      return Promise.resolve(state.revokedCertListCache)
    }
    commit('REVOKED_CERT_REQUEST')
    return api.list().then(response => {
      commit('REVOKED_CERT_LIST_REPLACED', response.items)
      return state.revokedCertListCache
    }).catch((err) => {
      commit('REVOKED_CERT_ERROR', err.response)
      throw err
    })
  },
  getRevokedCert: ({ state, commit }, id) => {
    if (state.revokedCertItemCache[id]) {
      return Promise.resolve(state.revokedCertItemCache[id])
    }
    commit('REVOKED_CERT_REQUEST')
    return api.item(id).then(item => {
      commit('REVOKED_CERT_ITEM_REPLACED', item)
      return state.revokedCertItemCache[id]
    }).catch((err) => {
      commit('REVOKED_CERT_ERROR', err.response)
      throw err
    })
  }
}

export const mutations = {
  REVOKED_CERT_REQUEST: (state, type) => {
    state.revokedCertStatus = type || types.LOADING
    state.revokedCertMessage = ''
  },
  REVOKED_CERT_LIST_RESET: (state) => {
    state.revokedCertListCache = false
  },
  REVOKED_CERT_LIST_REPLACED: (state, items) => {
    state.revokedCertStatus = types.SUCCESS
    state.revokedCertListCache = items
  },
  REVOKED_CERT_ITEM_REPLACED: (state, data) => {
    state.revokedCertStatus = types.SUCCESS
    Vue.set(state.revokedCertItemCache, data.ID, data)
  },
  REVOKED_CERT_ERROR: (state, response) => {
    state.revokedCertStatus = types.ERROR
    if (response && response.data) {
      state.revokedCertMessage = response.data.message
    }
  }
}
