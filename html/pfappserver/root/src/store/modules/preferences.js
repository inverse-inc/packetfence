/**
* "preferences" store module
*/
import Vue from 'vue'
import store from '@/store' // required for 'system/version'
import apiCall from '@/utils/api'

const getPreference = id => apiCall.getQuiet(['preference', id]).then(response => {
  const { value: _value = '{}' } = response.data.item
  const { meta, ...value } = JSON.parse(_value)
  return { meta, ...value }
})

const api = {
  allPreferences: () => apiCall.getQuiet('preferences').then(response => response.data.items),
  getPreference,
  removePreference: id => apiCall.deleteQuiet(['preference', id]).then(response => response),
  setPreference: _data => {
    const { id = null, value = null } = _data
    if (!id)
      throw new Error('Invalid or missing id.')
    let meta = {
      created_at: (new Date()).getTime(),
      updated_at: (new Date()).getTime(),
      version: store.getters['system/version']
    }
    return getPreference(id)
      .then(({ meta: { created_at } = {} }) => { // exists
        if (created_at) { // retain `created_at`
          meta = {
            created_at,
            updated_at: (new Date()).getTime(),
            version: store.getters['system/version']
          }
        }
        return apiCall.putQuiet(['preference', id], { id, value: JSON.stringify({ meta, ...value }) })
          .then(() => ({ id, value: { meta, ...value } }))
      })
      .catch(() => {
        apiCall.putQuiet(['preference', id], { id, value: JSON.stringify({ meta, ...value }) }) // not exists
          .then(() => ({ id, value: { meta, ...value } }))
      })
  }
}

const types = {
  INITIALIZING: 'initializing',
  LOADING: 'loading',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
const initialState = () => {
  return {
    initialized: false,
    cache: {},
    message: '',
    requestStatus: ''
  }
}

const getters = {
  isInitializing: state => state.requestStatus === types.INITIALIZING,
  isLoading: state => [types.INITIALIZING, types.LOADING].includes(state.requestStatus)
}

const actions = {
  init: ({ state, commit }) => {
    if (!state.initialized) {
      commit('PREFERENCE_INITIALIZE')
      return api.allPreferences()
        .then(items => {
          items.forEach(item => {
              const { id, value: _value = '{}' } = item
              const { meta, ...value } = JSON.parse(_value)
            commit('PREFERENCE_UPDATED', { id, value: { meta, ...value } })
          })
          commit('PREFERENCE_INITIALIZED')
        })
        .catch(error => commit('PREFERENCE_ERROR', error))
    }
    return Promise.resolve()
  },
  all: ({ state, dispatch }) => {
    return Promise.resolve(dispatch('init'))
      .then(() => state.cache)
  },
  get: ({ state, commit, dispatch }, id) => {
    return Promise.resolve(dispatch('init'))
      .then(() => {
        if (!(id in state.cache))
          commit('PREFERENCE_DECLARE', id)
        /* skip individual requests
        commit('PREFERENCE_REQUEST')
        api.getPreference(id)
          .then(preference => commit('PREFERENCE_UPDATED', preference))
          .catch(error => commit('PREFERENCE_ERROR', error))
        */
        return state.cache[id]
      })
  },
  set: ({ state, commit, dispatch }, data) => {
    return Promise.resolve(dispatch('init'))
      .then(() => {
        if (!(data.id in state.cache))
          commit('PREFERENCE_DECLARE', data.id)
        commit('PREFERENCE_REQUEST')
        return api.setPreference(data)
          .then(preference => {
            commit('PREFERENCE_UPDATED', preference)
            return state.cache[data.id]
          })
          .catch(error => commit('PREFERENCE_ERROR', error))

      })
  },
  delete: ({ state, commit, dispatch }, id) => {
    return Promise.resolve(dispatch('init'))
      .then(() => {
        if (id in state.cache) {
          commit('PREFERENCE_REQUEST')
          return api.removePreference(id)
            .then(() => {
              commit('PREFERENCE_DELETED', id)
              return undefined
            })
            .catch(error => commit('PREFERENCE_ERROR', error))
        }
      })
  }
}

const mutations = {
  PREFERENCE_INITIALIZE: state => {
    state.requestStatus = types.INITIALIZING
  },
  PREFERENCE_INITIALIZED: state => {
    state.requestStatus = types.SUCCESS
    state.initialized = true
  },
  PREFERENCE_DECLARE: (state, id) => {
    Vue.set(state.cache, id, {})
  },
  PREFERENCE_REQUEST: (state) => {
    state.requestStatus = types.LOADING
    state.message = ''
  },
  PREFERENCE_UPDATED: (state, data) => {
    state.requestStatus = types.SUCCESS
    const { id, value } = data
    Vue.set(state.cache, id, value)
  },
  PREFERENCE_DELETED: (state, id) => {
    state.requestStatus = types.SUCCESS
    Vue.delete(state.cache, id)
  },
  PREFERENCE_ERROR: (state, error) => {
    state.requestStatus = types.ERROR
    const { response: { data: { message } = {} } = {} } = error
    if (message)
      state.message = message
  },
  // eslint-disable-next-line no-unused-vars
  $RESET: (state) => {
    state = initialState()
  }
}

export default {
  namespaced: true,
  state: initialState(),
  getters,
  actions,
  mutations
}