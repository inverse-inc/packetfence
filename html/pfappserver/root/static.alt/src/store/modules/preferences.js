/**
* "preferences" store module
*/
import Vue from 'vue'
import store from '@/store' // required for 'system/version'
import apiCall from '@/utils/api'

const IDENTIFIER_PREFIX = 'pfappserver::' // transparently prefix all identifiers - avoid key collisions

const api = {
  allPreferences: () => {
    return apiCall.getQuiet('preferences').then(response => {
      return response.data.items
    })
  },
  getPreference: (id) => {
    return apiCall.getQuiet(`preference/${IDENTIFIER_PREFIX}${id}`).then(response => {
      return response.data
    })
  },
  setPreference: (_data) => {
    const { id = null, data = null } = _data
    if (!id) {
      throw new Error('Invalid or missing id.')
      return
    }
    if (data) {
      let body = {
        id: `${IDENTIFIER_PREFIX}${id}`,
        value: JSON.stringify({
          data,
          meta: {
            created_at: (new Date).getTime(),
            updated_at: (new Date).getTime(),
            version: store.getters['system/version']
          }
        })
      }
      return apiCall.getQuiet(`preference/${IDENTIFIER_PREFIX}${id}`).then(response => { // exists
        const { data: { item: { value = null } = {} } = {} } = response
        if (value) {
          const { meta: { created_at = null } = {} } = JSON.parse(value)
          if (created_at) { // retain `created_at`
            body = {
              id: `${IDENTIFIER_PREFIX}${id}`,
              value: JSON.stringify({
                data,
                meta: {
                  created_at: created_at,
                  updated_at: (new Date).getTime(),
                  version: store.getters['system/version']
                }
              })
            }
          }
        }
        return apiCall.putQuiet(`preference/${IDENTIFIER_PREFIX}${id}`, body).then(response => {
          return response.data
        })
      }).catch(err => { // not exists
        return apiCall.putQuiet(`preference/${IDENTIFIER_PREFIX}${id}`, body).then(response => {
          return response.data
        })
      })
    } else {
      return apiCall.deleteQuiet(`preference/${IDENTIFIER_PREFIX}${id}`).then(response => {
        return response
      })
    }
  },
  removePreference: id => {
    return apiCall.deleteQuiet(`preferences/${IDENTIFIER_PREFIX}${id}`).then(response => {
      return response
    })
  }
}

const types = {
  LOADING: 'loading',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
const state = {
  message: '',
  requestStatus: ''
}

const getters = {
  isLoading: state => state.requestStatus === types.LOADING
}

const actions = {
  all: () => {
    return api.allPreferences().then(response => {
      return response.items
    })
  },
  get: ({ state, commit }, name) => {
    commit('PREFERENCE_REQUEST')
    return api.getPreference(id).then(response => {
      commit('PREFERENCE_SUCCESS')
      return response
    }).catch((err) => {
      const { response } = err
      commit('PREFERENCE_ERROR', { id, response })
      throw err
    })
  },
  set: ({ state, commit }, data) => {
    commit('PREFERENCE_REQUEST')
    return api.setPreference(data).then(response => {
      commit('PREFERENCE_SUCCESS')
      return response
    }).catch((err) => {
      const { response } = err
      commit('PREFERENCE_ERROR', { id, response })
      throw err
    })
  },
  remove: ({ state, commit }, name) => {
    commit('PREFERENCE_REQUEST')
    return api.removePreference(name).then(response => {
      commit('PREFERENCE_SUCCESS')
      return response
    }).catch((err) => {
      const { response } = err
      commit('PREFERENCE_ERROR', { id, response })
      throw err
    })
  }
}

const mutations = {
  PREFERENCE_REQUEST: (state, id) => {
    state.requestStatus = types.LOADING
    state.message = ''
  },
  PREFERENCE_SUCCESS: (state, id) => {
    state.requestStatus = types.SUCCESS
    state.message = ''
  },
  PREFERENCE_ERROR: (state, data) => {
    state.requestStatus = types.ERROR
    const { response: { data: { message } = {} } = {} } = data
    if (message) {
      state.message = message
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
