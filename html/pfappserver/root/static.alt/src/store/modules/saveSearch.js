/**
* "saveSearch" store module
*/
import Vue from 'vue'
import store from '@/store' // required for 'preferences'
import i18n from '@/utils/locale'
import { IDENTIFIER_PREFIX as PREFERENCES_IDENTIFIER_PREFIX } from '@/store/modules/preferences'

const IDENTIFIER_PREFIX = 'saveSearch::' // transparently prefix all identifiers - avoid key collisions

const types = {
  LOADING: 'loading',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
const initialState = () => {
  return {
    cache: {}, // all searches, organized by `namespace`
    message: '',
    requestStatus: ''
  }
}

const getters = {
  cache: state => state.cache,
  isLoading: state => state.requestStatus === types.LOADING
}

const actions = {
  sync: ({ state, commit }, namespace) => {
    commit('SAVED_SEARCH_REQUEST')
    if (namespace) {
      if (state.cache[namespace]) {
        commit('SAVED_SEARCH_SUCCESS')
        return state.cache[namespace]
      } else {
        // namespace doesn't exist
        commit('SAVED_SEARCH_REPLACED', { namespace, data: [] })
        commit('SAVED_SEARCH_SUCCESS')
        return state.cache[namespace]
      }
    } else if (Object.keys(state.cache).length === 0) {
      // Load all saved searches from preferences
      const namespacePrefix = `${PREFERENCES_IDENTIFIER_PREFIX}${IDENTIFIER_PREFIX}`
      return store.dispatch('preferences/all').then(items => {
        items.forEach(item => {
          if (item.id.indexOf(namespacePrefix) === 0) {
            const { data } = JSON.parse(item.value)
            const namespace = item.id.substr(namespacePrefix.length)
            commit('SAVED_SEARCH_REPLACED', { namespace, data })
          }
        })
        return state.cache
      })
    }
  },
  get: ({ state, commit, dispatch }, namespace) => {
    commit('SAVED_SEARCH_REQUEST')
    if (namespace in state.cache) {
      commit('SAVED_SEARCH_SUCCESS')
      return Promise.resolve(state.cache[namespace])
    }
    return dispatch('sync').then(() => { // update cache if necessary
      return dispatch('sync', namespace).then(() => {
        return state.cache[namespace]
      })
    })
  },
  set: ({ state, commit, dispatch }, data) => {
    const { namespace = 'default', search: { name = null, route = null } = {} } = data
    if (!name) throw new Error(i18n.t('Saved search `name` required.'))
    return dispatch('sync', namespace).then(() => {
      let exists = state.cache[namespace].filter(search => JSON.stringify(search.route) === JSON.stringify(route))
      if (exists.length > 0) { // exists, prevent duplicates
        store.dispatch('notification/info', { message: i18n.t('Search already exists as <code>{name}</code>.', { name: exists[0].name }) })
        return state.cache[namespace]
      }
      let stateCacheCopy = [ ...state.cache[namespace].filter(search => search.name !== name) ]
      stateCacheCopy.push({ name, route, meta: { created_at: (new Date()).getTime(), version: store.getters['system/version'] } })
      return store.dispatch('preferences/set', { id: `${IDENTIFIER_PREFIX}${namespace}`, data: stateCacheCopy }).then(() => {
        commit('SAVED_SEARCH_REPLACED', { namespace, data: stateCacheCopy })
        store.dispatch('notification/info', { message: i18n.t('Search <code>{name}</code> saved.', { name }) })
        return state.cache[namespace]
      })
    })
  },
  remove: ({ state, commit, dispatch }, data) => {
    const { namespace = 'default', search: { name = null } = {} } = data
    if (!name) throw new Error(i18n.t('Saved search `name` required.'))
    return dispatch('sync', namespace).then(() => {
      let stateCacheCopy = [ ...state.cache[namespace].filter(search => search.name !== name) ]
      return store.dispatch('preferences/set', { id: `${IDENTIFIER_PREFIX}${namespace}`, data: stateCacheCopy }).then(() => {
        commit('SAVED_SEARCH_REPLACED', { namespace, data: stateCacheCopy })
        store.dispatch('notification/info', { message: i18n.t('Saved search <code>{name}</code> removed.', { name }) })
        if (state.cache[namespace].length === 0) { // truncate preference
          return store.dispatch('preferences/remove', `${IDENTIFIER_PREFIX}${namespace}`).then(() => {
            commit('SAVED_SEARCH_TRUNCATED', namespace)
            commit('SAVED_SEARCH_SUCCESS')
            return null
          })
        }
        return state.cache[namespace]
      })
    })
  },
  truncate: ({ state, commit }, namespace) => {
    if (namespace in state.cache) { // get by `namespace`
      commit('SAVED_SEARCH_REQUEST')
      return store.dispatch('preferences/remove', `${IDENTIFIER_PREFIX}${namespace}`).then(() => {
        commit('SAVED_SEARCH_TRUNCATED', namespace)
        commit('SAVED_SEARCH_SUCCESS')
        store.dispatch('notification/info', { message: i18n.t('Saved searches for <code>{namespace}</code> truncated.', { namespace }) })
        return null
      })
    }
    return undefined
  }
}

const mutations = {
  SAVED_SEARCH_REQUEST: (state) => {
    state.requestStatus = types.LOADING
    state.message = ''
  },
  SAVED_SEARCH_REPLACED: (state, _data) => {
    const { namespace, data } = _data
    Vue.set(state.cache, namespace, data)
  },
  SAVED_SEARCH_TRUNCATED: (state, namespace) => {
    Vue.delete(state.cache, namespace)
  },
  SAVED_SEARCH_SUCCESS: (state) => {
    state.requestStatus = types.SUCCESS
    state.message = ''
  },
  // eslint-disable-next-line
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
