/**
* "$_live_log" store module
*/
import Vue from 'vue'
import api from '../_api'
import { createDebouncer } from 'promised-debounce'
import i18n from '@/utils/locale'

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
    options: {
      background: 'white',
      size: 'normal',
      order: 'forward',
      output: 'raw'
    },
    events: [],
    filters: {},
    scopes: {
      hostname: {
        label: i18n.t('Hostname'),
        values: {}
      },
      filename: {
        label: i18n.t('Log Name'),
        values: {}
      },
      log_level: {
        label: i18n.t('Log Level'),
        values: {}
      },
      process: {
        label: i18n.t('Process Name'),
        values: {}
      },
      syslog_name: {
        label: i18n.t('Syslog Name'),
        values: {}
      }
    },
    size: 500,
    lines: 0,
    debouncer: false,
    debouncerMs: 300, // 300ms
    touch: false,
    touchMs: 15000, // 15s
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
  isFiltered: state => (scope, key) => {
    const { scopes: { [scope]: { values: { [key]: { filter = false } = {} } = {} } = {} } = {} } = state
    return filter
  },
  eventsFiltered: state => {
    const fk = Object.keys(state.filters)
    if (fk.length === 0) {
      return state.events
    }
    return state.events.filter(event => {
      const { data: { meta: { timestamp, log_without_prefix, ...meta } = {} } = {} } = event
      for (let i = 0; i < fk.length; i++) {
        let k = fk[i]
        let a = state.filters[k]
        if (!a.includes(meta[k])) {
          return false
        }
      }
      return event
    })
  },
  size: state => state.size,
  lines: state => state.lines,
  options: state => state.options
}

const actions = {
  setSession: ({ commit, dispatch }, session) => {
    commit('SET_SESSION', session)
    dispatch('getSession')
  },
  setOptions: ({ commit }, options) => {
    commit('SET_OPTIONS', options)
  },
  stopSession: ({ state, commit }) => {
    commit('LOG_SESSION_STOPPING')
    return api.deleteLogTailSession(state.session.session_id).then(response => {
      commit('LOG_SESSION_STOPPED')
      return response
    }).catch(err => {
      commit('LOG_SESSION_ERROR', err.response)
      return err
    })
  },
  getSession: ({ state, commit, dispatch }) => {
    if (state.running) {
      commit('LOG_SESSION_REQUEST')
      return api.getLogTailSession(state.session.session_id).then(response => {
        commit('LOG_SESSION_RESPONSE', response)
        if (!state.paused) {
          commit('LOG_SESSION_QUEUE', dispatch) // queue the next request
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
        commit('LOG_SESSION_QUEUE', dispatch) // queue the next request
      }
    }
  },
  touchSession: ({ state, commit }) => {
    if (state.paused) {
      commit('LOG_SESSION_REQUEST')
      return api.touchLogTailSession(state.session.session_id).then(response => {
        commit('LOG_SESSION_SUCCESS')
        return response
      }).catch(err => {
        commit('LOG_SESSION_ERROR', err.response)
        return err
      })
    }
  },
  toggleFilter: ({ getters, commit }, { scope, key }) => {
    if (getters.isFiltered(scope, key)) { // disable
      commit('LOG_FILTER_DISABLE', { scope, key })
      commit('UPDATE_FILTERS')
    }
    else { //enable
      commit('LOG_FILTER_ENABLE', { scope, key })
      commit('UPDATE_FILTERS')
    }
  },
  setSize: ({ commit }, size) => {
    commit('UPDATE_SIZE', +size)
  },
  clearEvents: ({ commit }) => {
    commit('CLEAR_EVENTS')
    commit('CLEAR_COUNTS')
  }
}

const addMeta = (scopes, event) => {
  const { data: { meta: { timestamp, log_without_prefix, ...meta } = {} } = {} } = event
  for (let key of Object.keys(meta)) {
    if (!(key in scopes)) {
      Vue.set(scopes[key], 'values', { [meta[key]]: { count: 1 } })
    }
    else if (!(meta[key] in scopes[key].values)) {
      Vue.set(scopes[key], 'values', Object.entries({
        ...scopes[key].values,
        [meta[key]]: { count: 1 }
      }).sort(([a], [b]) => {
        if (!a) return -1
        if (!b) return 1
        return +a - +b
      }).reduce((r, [k, v]) => {
        return { ...r, [k]: v }
      }, {}))
    }
    else {
      Vue.set(scopes[key].values[meta[key]], 'count', scopes[key].values[meta[key]].count + 1)
    }
  }
}

const delMeta = (scopes, event) => {
  const { data: { meta: { timestamp, log_without_prefix, ...meta } = {} } = {} } = event
  for (let key of Object.keys(meta)) {
    Vue.set(scopes[key].values[meta[key]], 'count', scopes[key].values[meta[key]].count - 1)
  }
}

const mutations = {
  SET_SESSION: (state, session) => {
    state.session = session
  },
  SET_OPTIONS: (state, options) => {
    state.options = options
  },
  LOG_SESSION_QUEUE: (state, dispatch) => {
    if (!state.debouncer) {
      state.debouncer = createDebouncer()
    }
    state.debouncer({
      handler: () => {
        dispatch('getSession')
      },
      time: state.debouncerMs
    })
  },
  LOG_SESSION_REQUEST: (state) => {
    state.status = 'loading'
    state.message = ''
  },
  LOG_SESSION_RESPONSE: (state, response) => {
    state.status = 'success'
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
  LOG_FILTER_ENABLE: (state, { scope, key }) => {
    state.scopes[scope].values[key].filter = true
  },
  LOG_FILTER_DISABLE: (state, { scope, key }) => {
    state.scopes[scope].values[key].filter = false
  },
  UPDATE_FILTERS: (state) => {
    state.filters = Object.entries(state.scopes).reduce((r, [k, { values: f }]) => {
      let v = Object.entries(f).reduce((r, [k, v]) => {
        return (v.filter) ? [ ...r, k ] : r
      }, [])
      return {
        ...r,
        ...((v.length > 0) ? { [k]: v } : {})
      }
    }, {})
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

