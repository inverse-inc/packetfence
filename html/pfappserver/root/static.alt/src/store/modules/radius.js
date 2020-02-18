/**
* "radius" store module
*/
import Vue from 'vue'
import i18n from '@/utils/locale'
import store from '@/store'
import apiCall from '@/utils/api'

const api = {
  getAttributes: () => {
    return apiCall.postQuiet('radius_attributes').then(response => {
      return response.data
    })
  }
}

const types = {
  LOADING: 'loading',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
const initialState = () => {
  return {
    attributes: false,
    message: '',
    requestStatus: ''
  }
}

const getters = {
  attributes: state => state.attributes
}

const actions = {
  getAttributes: ({ commit, state }) => {
    if (state.attributes) {
      return Promise.resolve(state.attributes)
    }
    commit('RADIUS_ATTRIBUTES_REQUEST')
    return new Promise((resolve, reject) => {
      api.getAttributes().then(data => {
        commit('RADIUS_ATTRIBUTES_SUCCESS', data)
        resolve(state.attributes)
      }).catch(err => {
        commit('RADIUS_ATTRIBUTES_ERROR', err.response)
        reject(err)
      })
    })
  }
}

const mutations = {
  RADIUS_ATTRIBUTES_REQUEST: (state) => {
    state.requestStatus = types.LOADING
    state.message = ''
  },
  RADIUS_ATTRIBUTES_SUCCESS: (state, data) => {
    const { items = {} } = data
    Vue.set(state, 'attributes', items.reduce((items, item) => {
      const { name = null, ...remainder } = item
      items[name] = item
      return items
    }, {}))
    state.requestStatus = types.SUCCESS
    state.message = ''
  },
  RADIUS_ATTRIBUTES_ERROR: (state, data) => {
    state.requestStatus = types.ERROR
    const { response: { data: { message } = {} } = {} } = data
    if (message) {
      state.message = message
    }
  }
}

export default {
  namespaced: true,
  state: initialState(),
  getters,
  actions,
  mutations
}
