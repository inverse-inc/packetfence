/**
* "lookup" store module
*/
import Vue from 'vue'
import apiCall from '@/utils/api'
import { pfFieldType as fieldType } from '@/globals/pfField'

const api = {
  doLookup: (path, method = 'post') => {
    return apiCall[method](path, {}, { baseURL: '', quiet: true }).then(response => {
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
    cache: {},
    message: '',
    lookupStatus: ''
  }
}

const getters = {
  isLoading: state => state.lookupStatus === types.LOADING,
  getFields: state => (path, fieldName, valueName) => {
    return state.cache[path]
      .sort((a, b) => a[fieldName].localeCompare(b[fieldName]))
      .map(item => {
        const { [fieldName]: text, [valueName]: value, vendor, allowed_values } = item
        if (allowed_values) {
          return {
            text: (vendor) ? `${text} (${vendor})` : text,
            value,
            options: allowed_values.map(option => {
              const { [fieldName]: text, [valueName]: value } = option
              return { text, value }
            }).sort((a, b) => {
              return a.text.localeCompare(b.text)
            }),
            types: [fieldType.OPTIONS]
          }
        }
        else {
          return {
            text: (vendor) ? `${text} (${vendor})` : text,
            value,
            types: [fieldType.SUBSTRING]
          }
        }
      })
  }
}

const actions = {
  getSearchPath: ({ dispatch }, path) => {
    return dispatch('searchPath', { path, method: 'get' })
  },
  postSearchPath: ({ dispatch }, path) => {
    return dispatch('searchPath', { path, method: 'post' })
  },
  searchPath: ({ commit, state }, { path, method }) => {
    if (path in state.cache) {
      return Promise.resolve(state.cache[path])
    }
    commit('LOOKUP_REQUEST', path)
    return new Promise((resolve, reject) => {
      api.doLookup(path, method).then(data => {
        commit('LOOKUP_SUCCESS', { path, data })
        resolve(state.cache[path])
      }).catch(err => {
        commit('LOOKUP_ERROR', err.response)
        reject(err)
      })
    })
  }
}

const mutations = {
  LOOKUP_REQUEST: (state, path) => {
    Vue.set(state.cache, path, [])
    state.lookupStatus = types.LOADING
    state.message = ''
  },
  LOOKUP_SUCCESS: (state, { path, data }) => {
    const { items = {} } = data
    Vue.set(state.cache, path, items)
    state.lookupStatus = types.SUCCESS
    state.message = ''
  },
  LOOKUP_ERROR: (state, data) => {
    state.lookupStatus = types.ERROR
    const { response: { data: { message } = {} } = {} } = data
    if (message) {
      state.message = message
    }
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
