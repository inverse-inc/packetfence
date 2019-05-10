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
  itemStatus: '',
  testStatus: ''
}

const getters = {
  isLoading: state => state.itemStatus === types.LOADING,
  isTesting: state => state.testStatus === types.LOADING
}

const actions = {
  getCertificate: ({ state, commit }, id) => {
    if (state.cache.certificate[id]) {
      return Promise.resolve(state.cache.certificate[id]).then(cache => JSON.parse(JSON.stringify(cache)))
    }
    commit('ITEM_REQUEST')
    return api.certificate(id).then(item => {
      item.id = id
      commit('ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  getCertificateInfo: ({ state, commit }, id) => {
    if (state.cache.info[id]) {
      return Promise.resolve(state.cache.info[id]).then(cache => JSON.parse(JSON.stringify(cache)))
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
  createLetsEncryptCertificate: ({ commit }, data) => {
    const request = {
      id: data.id,
      lets_encrypt: data.lets_encrypt,
      common_name: data.common_name
    }
    commit('ITEM_REQUEST')
    return api.createLetsEncryptCertificate(request).then(response => {
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
      return response.csr
    }).catch(err => {
      commit('ITEM_ERROR', err.response)
      throw err
    })
  },
  testLetsEncrypt: ({ commit }, domain) => {
    commit('TEST_STATUS', types.LOADING)
    return api.testLetsEncrypt(domain).then(response => {
      commit('TEST_STATUS', types.SUCCESS)
      return response.result
    }).catch(err => {
      commit('TEST_STATUS', types.ERROR)
      throw err.message
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
      Vue.set(state.cache.certificate, data.id, JSON.parse(JSON.stringify(data)))
    } else {
      Vue.set(state.cache.info, data.id, JSON.parse(JSON.stringify(data)))
    }
  },
  ITEM_ERROR: (state, response) => {
    state.itemStatus = types.ERROR
    if (response && response.data) {
      state.message = response.data.message
    }
  },
  TEST_STATUS: (state, type) => {
    state.testStatus = type || types.LOADING
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
