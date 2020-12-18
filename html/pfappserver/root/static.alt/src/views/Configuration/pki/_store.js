/**
* "$_pkis" store module
*/
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
const state = () => {
  return {
    caListCache: false, // ca list details
    caItemCache: {}, // ca item details
    caMessage: '',
    caStatus: '',

    profileListCache: false, // profile list details
    profileItemCache: {}, // profile item details
    profileMessage: '',
    profileStatus: '',

    certListCache: false, // cert list details
    certItemCache: {}, // cert item details
    certMessage: '',
    certStatus: '',

    revokedCertListCache: false, // revoked cert list details
    revokedCertItemCache: {}, // revoked cert item details
    revokedCertMessage: '',
    revokedCertStatus: ''
  }
}

const getters = {
  isWaiting: state => [types.LOADING, types.DELETING].includes(state.caStatus) || [types.LOADING, types.DELETING].includes(state.profileStatus) || [types.LOADING, types.DELETING].includes(state.certStatus) || [types.LOADING, types.DELETING].includes(state.revokedCertStatus),
  isLoading: state => state.caStatus === types.LOADING || state.profileStatus === types.LOADING || state.certStatus === types.LOADING || state.revokedCertStatus === types.LOADING,

  isCaWaiting: state => [types.LOADING, types.DELETING].includes(state.caStatus),
  isCaLoading: state => state.caStatus === types.LOADING,

  isProfileWaiting: state => [types.LOADING, types.DELETING].includes(state.profileStatus),
  isProfileLoading: state => state.profileStatus === types.LOADING,

  isCertWaiting: state => [types.LOADING, types.DELETING].includes(state.certStatus),
  isCertLoading: state => state.certStatus === types.LOADING,

  isRevokedCertWaiting: state => [types.LOADING, types.DELETING].includes(state.revokedCertStatus),
  isRevokedCertLoading: state => state.revokedCertStatus === types.LOADING,

  cas: state => state.caListCache,
  profiles: state => state.profileListCache,
  certs: state => state.certListCache,
  revokedCerts: state => state.revokedCertListCache
}

const actions = {
  allCas: ({ state, commit }) => {
    if (state.caListCache) {
      return Promise.resolve(state.caListCache)
    }
    commit('CA_REQUEST')
    return api.pkiCas().then(response => {
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
    return api.pkiCa(id).then(item => {
      commit('CA_ITEM_REPLACED', item)
      return state.caItemCache[id]
    }).catch((err) => {
      commit('CA_ERROR', err.response)
      throw err
    })
  },
  createCa: ({ commit, dispatch }, data) => {
    commit('CA_REQUEST')
    return api.createPkiCa(data).then(item => {
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
  },

  allProfiles: ({ state, commit }) => {
    if (state.profileListCache) {
      return Promise.resolve(state.profileListCache)
    }
    commit('PROFILE_REQUEST')
    return api.pkiProfiles().then(response => {
      commit('PROFILE_LIST_REPLACED', response.items)
      return state.profileListCache
    }).catch((err) => {
      commit('PROFILE_ERROR', err.response)
      throw err
    })
  },
  getProfile: ({ state, commit }, id) => {
    if (state.profileItemCache[id]) {
      return Promise.resolve(state.profileItemCache[id])
    }
    commit('PROFILE_REQUEST')
    return api.pkiProfile(id).then(item => {
      commit('PROFILE_ITEM_REPLACED', item)
      return state.profileItemCache[id]
    }).catch((err) => {
      commit('PROFILE_ERROR', err.response)
      throw err
    })
  },
  createProfile: ({ commit, dispatch }, data) => {
    commit('PROFILE_REQUEST')
    return api.createPkiProfile(data).then(item => {
      // reset list
      commit('PROFILE_LIST_RESET')
      dispatch('allProfiles')
      // update item
      commit('PROFILE_ITEM_REPLACED', item)
      return item
    }).catch(err => {
      commit('PROFILE_ERROR', err.response)
      throw err
    })
  },
  updateProfile: ({ commit, dispatch }, data) => {
    commit('PROFILE_REQUEST')
    return api.updatePkiProfile(data).then(item => {
      // reset list
      commit('PROFILE_LIST_RESET')
      dispatch('allProfiles')
      // update item
      commit('PROFILE_ITEM_REPLACED', item)
      return item
    }).catch(err => {
      commit('PROFILE_ERROR', err.response)
      throw err
    })
  },
  allCerts: ({ state, commit }) => {
    if (state.certListCache) {
      return Promise.resolve(state.certListCache)
    }
    commit('CERT_REQUEST')
    return api.pkiCerts().then(response => {
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
    return api.pkiCert(id).then(item => {
      commit('CERT_ITEM_REPLACED', item)
      return state.certItemCache[id]
    }).catch((err) => {
      commit('CERT_ERROR', err.response)
      throw err
    })
  },
  downloadCert: ({ commit }, data) => {
    commit('CERT_REQUEST')
    return api.downloadPkiCert(data).then(binary => {
      commit('CERT_SUCCESS')
      return binary
    }).catch(err => {
      commit('CERT_ERROR', err.response)
      throw err
    })
  },
  createCert: ({ commit, dispatch }, data) => {
    commit('CERT_REQUEST')
    return api.createPkiCert(data).then(item => {
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
    return api.emailPkiCert(id).then(response => {
      commit('CERT_SUCCESS')
      return response
    }).catch(err => {
      commit('CERT_ERROR', err.response)
      throw err
    })
  },
  revokeCert: ({ commit, dispatch }, data) => {
    commit('CERT_REQUEST')
    return api.revokePkiCert(data).then(response => {
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
  },

  allRevokedCerts: ({ state, commit }) => {
    if (state.revokedCertListCache) {
      return Promise.resolve(state.revokedCertListCache)
    }
    commit('REVOKED_CERT_REQUEST')
    return api.pkiRevokedCerts().then(response => {
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
    return api.pkiRevokedCert(id).then(item => {
      commit('REVOKED_CERT_ITEM_REPLACED', item)
      return state.revokedCertItemCache[id]
    }).catch((err) => {
      commit('REVOKED_CERT_ERROR', err.response)
      throw err
    })
  }
}

const mutations = {
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
  },

  PROFILE_REQUEST: (state, type) => {
    state.profileStatus = type || types.LOADING
    state.profileMessage = ''
  },
  PROFILE_LIST_RESET: (state) => {
    state.profileListCache = false
  },
  PROFILE_LIST_REPLACED: (state, items) => {
    state.profileStatus = types.SUCCESS
    state.profileListCache = items
  },
  PROFILE_ITEM_REPLACED: (state, data) => {
    state.profileStatus = types.SUCCESS
    Vue.set(state.profileItemCache, data.ID, data)
    store.dispatch('config/resetPkiProfiles')
  },
  PROFILE_ERROR: (state, response) => {
    state.profileStatus = types.ERROR
    if (response && response.data) {
      state.profileMessage = response.data.message
    }
  },

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
  },

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

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
