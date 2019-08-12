/**
* "preferences" store module
*/
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
      return response.data.item
    })
  },
  setPreference: (_data) => {
    const { id = null, data = null } = _data
    if (!id) {
      throw new Error('Invalid or missing id.')
    }
    if (data) {
      let body = {
        id: `${IDENTIFIER_PREFIX}${id}`,
        value: JSON.stringify({
          data,
          meta: {
            created_at: (new Date()).getTime(),
            updated_at: (new Date()).getTime(),
            version: store.getters['system/version']
          }
        })
      }
      return apiCall.getQuiet(['preference',  `${IDENTIFIER_PREFIX}${id}`]).then(response => { // exists
        const { data: { item: { value = null } = {} } = {} } = response
        if (value) {
          // eslint-disable-next-line
          const { meta: { created_at = null } = {} } = JSON.parse(value)
          // eslint-disable-next-line
          if (created_at) { // retain `created_at`
            body = {
              id: `${IDENTIFIER_PREFIX}${id}`,
              value: JSON.stringify({
                data,
                meta: {
                  created_at: created_at,
                  updated_at: (new Date()).getTime(),
                  version: store.getters['system/version']
                }
              })
            }
          }
        }
        return apiCall.putQuiet(['preference', `${IDENTIFIER_PREFIX}${id}`], body).then(response => {
          return response.data
        })
      }).catch(() => { // not exists
        return apiCall.putQuiet(['preference', `${IDENTIFIER_PREFIX}${id}`], body).then(response => {
          return response.data
        })
      })
    } else {
      return apiCall.deleteQuiet(['preference', `${IDENTIFIER_PREFIX}${id}`]).then(response => {
        return response
      })
    }
  },
  removePreference: id => {
    return apiCall.deleteQuiet(['preference', `${IDENTIFIER_PREFIX}${id}`]).then(response => {
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
const initialState = () => {
  return {
    message: '',
    requestStatus: ''
  }
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
  get: ({ state, commit }, id) => {
    commit('PREFERENCE_REQUEST')
    return api.getPreference(id).then(response => {
      commit('PREFERENCE_SUCCESS')
      return response
    }).catch((err) => {
      commit('PREFERENCE_ERROR', err)
      throw err
    })
  },
  set: ({ state, commit }, data) => {
    commit('PREFERENCE_REQUEST')
    return api.setPreference(data).then(response => {
      commit('PREFERENCE_SUCCESS')
      return response
    }).catch((err) => {
      commit('PREFERENCE_ERROR', err)
      throw err
    })
  },
  remove: ({ state, commit }, id) => {
    commit('PREFERENCE_REQUEST')
    return api.removePreference(id).then(response => {
      commit('PREFERENCE_SUCCESS')
      return response
    }).catch((err) => {
      commit('PREFERENCE_ERROR', err)
      throw err
    })
  }
}

const mutations = {
  PREFERENCE_REQUEST: (state) => {
    state.requestStatus = types.LOADING
    state.message = ''
  },
  PREFERENCE_SUCCESS: (state) => {
    state.requestStatus = types.SUCCESS
    state.message = ''
  },
  PREFERENCE_ERROR: (state, data) => {
    state.requestStatus = types.ERROR
    const { response: { data: { message } = {} } = {} } = data
    if (message) {
      state.message = message
    }
  },
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
