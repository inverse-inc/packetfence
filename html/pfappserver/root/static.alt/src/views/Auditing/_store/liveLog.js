/**
* "$_live_log" store module
*/
import Vue from 'vue'
import api from '../_api'
import { createDebouncer } from 'promised-debounce'

// Default values
const state = () => {
  return {
    session: {},
    events: [],
    scopes: {},
    debouncer: false,
    debouncerMs: 300, // 300ms
    message: '',
    status: ''
  }
}

const getters = {
  isLoading: state => state.status === 'loading',
  session: state => state.session,
  events: state => state.events,
  scopes: state => state.scopes
}

const actions = {
  setSession: ({ commit, dispatch }, session) => {
    commit('SET_SESSION', { session, dispatch })
  },
  getSession: ({ state, commit, dispatch }) => {
    commit('LOG_SESSION_REQUEST')
    return api.getLogTailSession(state.session.session_id).then(response => {
      commit('LOG_SESSION_RESPONSE', response)
      commit('LOG_SESSION_QUEUE', dispatch) // queue the next request
      return response
    }).catch(err => {
      commit('LOG_SESSION_ERROR', err.response)
      //commit('LOG_SESSION_QUEUE', dispatch) // queue the next request
      return err
    })
  }
}

const mutations = {
  SET_SESSION: (state, { session, dispatch }) => {
    state.session = session
    dispatch('getSession')
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
      for (let event of events) {
        const { data: { meta: { timestamp, log_without_prefix, ...meta } = {} } = {} } = event
        for (let key of Object.keys(meta)) {
          if (!(key in state.scopes)) {
            state.scopes[key] = { [meta[key]]: 1 }
          }
          else if (!(meta[key] in state.scopes[key])) {
            state.scopes[key][meta[key]] = 1
          }
          else {
            state.scopes[key][meta[key]]++
          }
        }
      }
    }
  },
  LOG_SESSION_ERROR: (state, response) => {
    state.status = 'error'
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

