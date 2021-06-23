import Vue from 'vue'
import { computed } from '@vue/composition-api'
import store from '@/store'
import api from './_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_pkis/isCertLoading']),
    getList: () => $store.dispatch('$_pkis/allCerts'),
    createItem: params => $store.dispatch('$_pkis/createCert', params),
    getItem: params => $store.dispatch('$_pkis/getCert', params.id)
  }
}

const types = {
  LOADING: 'loading',
  DELETING: 'deleting',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
export const state = () => {
  return {
    certListCache: false, // cert list details
    certItemCache: {}, // cert item details
    certMessage: '',
    certStatus: ''
  }
}

export const getters = {
  isCertWaiting: state => [types.LOADING, types.DELETING].includes(state.certStatus),
  isCertLoading: state => state.certStatus === types.LOADING,
  certs: state => state.certListCache
}

export const actions = {
  allCerts: ({ state, commit }) => {
    if (state.certListCache) {
      return Promise.resolve(state.certListCache)
    }
    commit('CERT_REQUEST')
    return api.list().then(response => {
      commit('CERT_LIST_REPLACED', response.items)
      return state.certListCache
    }).catch((err) => {
      commit('CERT_ERROR', err.response)
      throw err
    })
  },
  getCert: ({ state, commit }, id) => {
    if (state.certItemCache[id]) {
      return Promise.resolve(state.certItemCache[id])
    }
    commit('CERT_REQUEST')
    return api.item(id).then(item => {
      commit('CERT_ITEM_REPLACED', item)
      return state.certItemCache[id]
    }).catch((err) => {
      commit('CERT_ERROR', err.response)
      throw err
    })
  },
  downloadCert: ({ commit }, data) => {
    commit('CERT_REQUEST')
    return api.download(data).then(binary => {
      commit('CERT_SUCCESS')
      return binary
    }).catch(err => {
      commit('CERT_ERROR', err.response)
      throw err
    })
  },
  createCert: ({ commit, dispatch }, data) => {
    commit('CERT_REQUEST')
    return api.create(data).then(item => {
      // reset list
      commit('CERT_LIST_RESET')
      dispatch('allCerts')
      // update item
      commit('CERT_ITEM_REPLACED', item)
      return item
    }).catch(err => {
      commit('CERT_ERROR', err.response)
      throw err
    })
  },
  emailCert: ({ commit }, id) => {
    commit('CERT_REQUEST')
    return api.email(id).then(response => {
      commit('CERT_SUCCESS')
      return response
    }).catch(err => {
      commit('CERT_ERROR', err.response)
      throw err
    })
  },
  revokeCert: ({ commit, dispatch }, data) => {
    commit('CERT_REQUEST')
    return api.revoke(data).then(response => {
      // reset list(s)
      commit('CERT_LIST_RESET')
      dispatch('allCerts')
      commit('REVOKED_CERT_LIST_RESET')
      dispatch('allRevokedCerts')
      // update item
      commit('CERT_ITEM_REVOKED', data.id)
      return response
    }).catch(err => {
      commit('CERT_ERROR', err.response)
      throw err
    })
  }
}

export const mutations = {
  CERT_REQUEST: (state, type) => {
    state.certStatus = type || types.LOADING
    state.certMessage = ''
  },
  CERT_SUCCESS: (state) => {
    state.certStatus = types.SUCCESS
    state.certMessage = ''
  },
  CERT_LIST_RESET: (state) => {
    state.certListCache = false
  },
  CERT_LIST_REPLACED: (state, items) => {
    state.certStatus = types.SUCCESS
    state.certListCache = items.map(item => {
      const { ID, ca_id } = item
      return { ...item, ID: `${ID}`, ca_id: `${ca_id}` }
    })
  },
  CERT_ITEM_REPLACED: (state, data) => {
    state.certStatus = types.SUCCESS
    const { ID, ca_id } = data
    Vue.set(state.certItemCache, data.ID, { ...data, ID: `${ID}`, ca_id: `${ca_id}` })
    store.dispatch('config/resetPkiCerts')
  },
  CERT_ITEM_EMAILED: (state) => {
    state.certStatus = types.SUCCESS
  },
  CERT_ITEM_REVOKED: (state) => {
    state.certStatus = types.SUCCESS
    store.dispatch('config/resetPkiCerts')
  },
  CERT_ERROR: (state, response) => {
    state.certStatus = types.ERROR
    if (response && response.data) {
      state.certMessage = response.data.message
    }
  }
}
