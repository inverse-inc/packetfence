/**
* "$_live_log" store module
*/
import Vue from 'vue'
import store from '@/store'
import api from '../_api'
import { createDebouncer } from 'promised-debounce'
import { defaultScopes, addMeta, delMeta, isFilteredGetter, eventsFilteredGetter, computeFilters, setScopeFilter } from '@/utils/logEvents'

// Default values
const state = () => {
  return {
    running: true,
    paused: false,
    session: {
      files: [],
      filter: null,
      filter_is_regexp: false
    },
    cursor: null,
    options: {
      background: 'white',
      size: 'normal',
      order: 'forward',
      output: 'raw',
      levelHighlight: true
    },
    events: [],
    filters: {},
    scopes: defaultScopes(),
    size: 500,
    lines: 0,
    debouncer: false,
    debouncerMs: 300, // 300ms
    debouncerSlowMs: 2000, // 2s idle poll for SaaS
    touch: false,
    touchMs: 15000, // 15s
    searchQuery: '',
    searchIsRegex: false,
    message: '',
    status: ''
  }
}

const getters = {
  isLoading: state => state.status === 'loading',
  isStopping: state => state.status === 'stopping',
  isRunning: state => state.running,
  isPaused: state => state.paused,
  session: state => state.session,
  events: state => state.events,
  scopes: state => state.scopes,
  filters: state => state.filters,
  isFiltered: isFilteredGetter,
  eventsFiltered: eventsFilteredGetter,
  size: state => state.size,
  lines: state => state.lines,
  options: state => state.options,
  searchQuery: state => state.searchQuery,
  searchIsRegex: state => state.searchIsRegex
}

const actions = {
  setSession: ({ commit, dispatch }, session) => {
    commit('SET_SESSION', session)
    dispatch('getSession')
  },
  setOptions: ({ commit }, options) => {
    commit('SET_OPTIONS', options)
  },
  stopSession: ({ state, commit }, peerOverride) => {
    commit('LOG_SESSION_STOPPING')
    // Caller may pass the peer explicitly so the header survives a page reload that wiped state.session.peer.
    const peer = peerOverride || state.session.peer
    return api.delete(state.session.session_id, peer).then(response => {
      commit('LOG_SESSION_STOPPED')
      return response
    }).catch(err => {
      commit('LOG_SESSION_ERROR', err.response)
      return err
    })
  },
  getSession: ({ state, commit, dispatch }) => {
    if (state.running) {
      const saas = store.getters['system/isSaas']
      commit('LOG_SESSION_REQUEST')
      let promise
      if (saas) {
        const pollBody = {
          files: state.session.files,
          filter: state.session.filter || '',
          filter_is_regexp: state.session.filter_is_regexp || false,
          cursor: state.cursor
        }
        promise = api.item(state.session.session_id, pollBody)
      } else {
        promise = api.item(state.session.session_id, null, state.session.peer)
      }
      return promise.then(response => {
        commit('LOG_SESSION_RESPONSE', response)
        if (!state.paused) {
          const delayMs = (saas && (!response.events || response.events.length === 0))
            ? state.debouncerSlowMs
            : state.debouncerMs
          commit('LOG_SESSION_QUEUE', { dispatch, delayMs })
        }
        return response
      }).catch(err => {
        commit('LOG_SESSION_ERROR', err.response)
        return err
      })
    }
  },
  pauseSession: ({ state, commit, dispatch }) => {
    if (!state.paused) {
      commit('LOG_SESSION_PAUSE', dispatch)
    }
  },
  unpauseSession: ({ state, commit, dispatch }) => {
    if (state.paused) {
      commit('LOG_SESSION_UNPAUSE')
      if (state.running) {
        commit('LOG_SESSION_QUEUE', { dispatch, delayMs: state.debouncerMs })
      }
    }
  },
  touchSession: ({ state, commit }) => {
    if (state.paused) {
      commit('LOG_SESSION_REQUEST')
      return api.touch(state.session.session_id, state.session.peer).then(response => {
        commit('LOG_SESSION_SUCCESS')
        return response
      }).catch(err => {
        commit('LOG_SESSION_ERROR', err.response)
        return err
      })
    }
  },
  // Explicit target state: the cluster view computes the desired flag once
  // from the merged scopes and sets it on every peer module, so peers can
  // never toggle in opposite directions.
  setFilter: ({ commit }, { scope, key, filter }) => {
    commit('LOG_FILTER_SET', { scope, key, filter })
    commit('UPDATE_FILTERS')
  },
  toggleFilter: ({ getters, dispatch }, { scope, key }) => {
    return dispatch('setFilter', { scope, key, filter: !getters.isFiltered(scope, key) })
  },
  setSize: ({ commit }, size) => {
    commit('UPDATE_SIZE', +size)
  },
  clearEvents: ({ commit }) => {
    commit('CLEAR_EVENTS')
    commit('CLEAR_COUNTS')
  }
}

const mutations = {
  SET_SEARCH_QUERY: (state, query) => {
    state.searchQuery = query
  },
  SET_SEARCH_IS_REGEX: (state, isRegex) => {
    state.searchIsRegex = isRegex
  },
  SET_SESSION: (state, session) => {
    state.session = session
    if (session.cursor != null) {
      state.cursor = session.cursor
    }
  },
  SET_OPTIONS: (state, options) => {
    state.options = options
  },
  LOG_SESSION_QUEUE: (state, { dispatch, delayMs }) => {
    if (!state.debouncer) {
      state.debouncer = createDebouncer()
    }
    state.debouncer({
      handler: () => {
        dispatch('getSession')
      },
      time: delayMs || state.debouncerMs
    })
  },
  LOG_SESSION_REQUEST: (state) => {
    state.status = 'loading'
    state.message = ''
  },
  LOG_SESSION_RESPONSE: (state, response) => {
    state.status = 'success'
    if (response.cursor != null) {
      state.cursor = response.cursor
    }
    const { events } = response
    if (events) {
      state.events = [ ...state.events, ...events ]
      state.lines += events.length
      if (state.lines > state.size) {
        for (let event of state.events.slice(0, state.lines - state.size)) { // truncate counts
          delMeta(state.scopes, event)
        }
        state.events = state.events.slice(-state.size) // truncate events
        state.lines = state.size
      }
      for (let event of events) {
        addMeta(state.scopes, event)
      }
    }
  },
  LOG_SESSION_STOPPING: (state) => {
    state.status = 'stopping'
    if (state.touch) {
      clearInterval(state.touch)
    }
  },
  LOG_SESSION_STOPPED: (state) => {
    state.status = 'success'
    state.running = false
  },
  LOG_SESSION_PAUSE: (state, dispatch) => {
    state.paused = true
    if (state.touch) {
      clearInterval(state.touch)
    }
    state.touch = setInterval(() => {
      dispatch('touchSession')
    }, state.touchMs)
  },
  LOG_SESSION_UNPAUSE: (state) => {
    state.paused = false
    if (state.touch) {
      clearInterval(state.touch)
    }
  },
  LOG_SESSION_SUCCESS: (state) => {
    state.status = 'success'
  },
  LOG_SESSION_ERROR: (state, response) => {
    state.status = 'error'
    state.running = false
    if (response && response.data) {
      state.message = response.data.message
    }
  },
  LOG_FILTER_SET: (state, { scope, key, filter }) => {
    setScopeFilter(state.scopes, scope, key, filter)
  },
  UPDATE_FILTERS: (state) => {
    state.filters = computeFilters(state.scopes)
  },
  UPDATE_SIZE: (state, size) => {
    state.size = size
    if (state.lines > state.size) {
      for (let event of state.events.slice(0, state.lines - state.size)) { // truncate counts
        delMeta(state.scopes, event)
      }
      state.events = state.events.slice(-state.size) // truncate events
      state.lines = state.size
    }
  },
  CLEAR_EVENTS: (state) => {
    state.events = []
  },
  CLEAR_COUNTS: (state) => {
    for(let [scope, { values = {} }] of Object.entries(state.scopes)) {
      for(let [key] of Object.entries(values)) {
        Vue.set(state.scopes[scope].values[key], 'count', 0)
      }
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
