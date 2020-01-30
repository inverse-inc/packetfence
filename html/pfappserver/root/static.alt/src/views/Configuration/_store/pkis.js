/**
* "$_pkis" store module
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
  certStatus: ''
}

const getters = {
  isWaiting: state => [types.LOADING, types.DELETING].includes(state.caStatus) || [types.LOADING, types.DELETING].includes(state.profileStatus) || [types.LOADING, types.DELETING].includes(state.certStatus),
  isLoading: state => state.caStatus === types.LOADING || state.profileStatus === types.LOADING || state.certStatus === types.LOADING,

  isCaWaiting: state => [types.LOADING, types.DELETING].includes(state.caStatus),
  isCaLoading: state => state.caStatus === types.LOADING,

  isProfileWaiting: state => [types.LOADING, types.DELETING].includes(state.profileStatus),
  isProfileLoading: state => state.profileStatus === types.LOADING,

  isCertWaiting: state => [types.LOADING, types.DELETING].includes(state.certStatus),
  isCertLoading: state => state.certStatus === types.LOADING,
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
  createCa: ({ commit }, data) => {
    commit('CA_REQUEST')
    return api.createPkiCa(data).then(item => {
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
  createProfile: ({ commit }, data) => {
    commit('PROFILE_REQUEST')
    return api.createPkiProfile(data).then(item => {
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
    })
  },
  createCert: ({ commit }, data) => {
    commit('CERT_REQUEST')
    return api.createPkiCert(data).then(item => {
      commit('CERT_ITEM_REPLACED', item)
      return item
    }).catch(err => {
      commit('CERT_ERROR', err.response)
      throw err
    })
  },
  emailCert: ({ commit }, cn) => {
    commit('CERT_REQUEST')
    return api.emailPkiCert(cn).then(response => {
      commit('CERT_SUCCESS')
      return response
    }).catch(err => {
      commit('CERT_ERROR', err.response)
      throw err
    })
  },
  revokeCert: ({ commit }, data) => {
    commit('CERT_REQUEST')
    return api.revokePkiCert(data).then(response => {
      commit('CERT_ITEM_REVOKED', data.id)
      return response
    }).catch(err => {
      commit('CERT_ERROR', err.response)
      throw err
    })
  }
}

const mutations = {
  CA_REQUEST: (state, type) => {
    state.caStatus = type || types.LOADING
    state.caMessage = ''
  },
  CA_LIST_REPLACED: (state, items) => {
    state.caStatus = types.SUCCESS
    state.caListCache = items
  },
  CA_ITEM_REPLACED: (state, data) => {
    state.caStatus = types.SUCCESS
    Vue.set(state.caItemCache, data.ID, data)
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
  PROFILE_LIST_REPLACED: (state, items) => {
    state.profileStatus = types.SUCCESS
    state.profileListCache = items
  },
  PROFILE_ITEM_REPLACED: (state, data) => {
    state.profileStatus = types.SUCCESS
    Vue.set(state.profileItemCache, data.ID, data)
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
  CERT_LIST_REPLACED: (state, items) => {
    state.certStatus = types.SUCCESS
    state.certListCache = items
  },
  CERT_ITEM_REPLACED: (state, data) => {
    state.certStatus = types.SUCCESS
    Vue.set(state.certItemCache, data.ID, data)
  },
  CERT_ITEM_EMAILED: (state) => {
    state.certStatus = types.SUCCESS
  },
  CERT_ITEM_REVOKED: (state, id) => {
    state.certStatus = types.SUCCESS
  },
  CERT_ERROR: (state, response) => {
    state.certStatus = types.ERROR
    if (response && response.data) {
      state.certMessage = response.data.message
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
