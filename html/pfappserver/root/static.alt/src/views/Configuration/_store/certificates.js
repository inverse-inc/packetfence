/**
* "$_certificates" store module
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
  cache: { info: {}, certificate: {} }, // items details
  message: '',
  itemStatus: ''
}

const getters = {
  isLoading: state => state.itemStatus === types.LOADING
}

const actions = {
  // getCertificate: ({ state, commit }, id) => {
  //   if (state.cache[id]) {
  //     return Promise.resolve(state.cache[id])
  //   }
  //   commit('ITEM_REQUEST')
  //   return api.certificate(id).then(item => {
  //     // Fetch extracted information about the certificate
  //     return api.certificateInfo(id).then(info => {
  //       item.id = id
  //       item.info = info
  //       commit('ITEM_REPLACED', item)
  //       return item
  //     }).catch((err) => {
  //       commit('ITEM_ERROR', err.response)
  //       throw err
  //     })
  //   }).catch((err) => {
  //     commit('ITEM_ERROR', err.response)
  //     throw err
  //   })
  // },
  getCertificate: ({ state, commit }, id) => {
    if (state.cache.certificate[id]) {
      return Promise.resolve(state.cache.certificate[id])
    }
    commit('ITEM_REQUEST')
    return api.certificate(id).then(item => {
      item.id = id
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getCertificateInfo: ({ state, commit }, id) => {
    if (state.cache.info[id]) {
      return Promise.resolve(state.cache.info[id])
    }
    commit('ITEM_REQUEST')
    return api.certificateInfo(id).then(item => {
      item.id = id
      commit('ITEM_REPLACED', item)
      return item
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  createCertificate: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.createCertificate(data).then(response => {
      commit('ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  generateCertificateSigningRequest: ({ commit }, data) => {
    commit('ITEM_REQUEST')
    return api.generateCertificateSigningRequest(data).then(response => {
      commit('ITEM_SUCCESS')
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
  ITEM_SUCCESS: (state) => {
    state.itemStatus = types.SUCCESS
    state.message = ''
  },
  ITEM_REPLACED: (state, data) => {
    state.itemStatus = types.SUCCESS
    if (data.private_key) {
      Vue.set(state.cache.certificate, data.id, data)
    } else {
      Vue.set(state.cache.info, data.id, data)
    }
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
