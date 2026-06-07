/**
* "$_historical_log" store module — per-session state for one historical
* query. The shape mirrors LiveLogs/_store/session.js (so TheView can reuse
* the same scopes/filters UI) but the polling loop is replaced with an
* explicit "Load more" action that advances the per-host cursor map.
*/
import Vue from 'vue'
import store from '@/store'
import api from '../_api'
import i18n from '@/utils/locale'

const state = () => ({
  running: true,
  paused: true, // no live polling
  session: {
    files: [],
    filter: null,
    filter_is_regexp: false,
    start: null,
    end: null
  },
  cursors: {}, // { hostA: { 'packetfence.log': 1780... }, hostB: {...} }
  options: { background: 'white', size: 'normal', order: 'forward', output: 'color' },
  events: [],
  filters: {},
  scopes: {
    hostname:    { label: i18n.t('Hostname'),    values: {} },
    filename:    { label: i18n.t('Log Name'),    values: {} },
    log_level:   { label: i18n.t('Log Level'),   values: {} },
    process:     { label: i18n.t('Process Name'),values: {} },
    syslog_name: { label: i18n.t('Syslog Name'), values: {} }
  },
  size: 5000,
  lines: 0,
  searchQuery: '',
  searchIsRegex: false,
  message: '',
  status: '',
  exhausted: false
})

const getters = {
  isLoading:   state => state.status === 'loading',
  isStopping:  state => false,
  isRunning:   state => state.running,
  isPaused:    state => state.paused,
  session:     state => state.session,
  events:      state => state.events,
  scopes:      state => state.scopes,
  filters:     state => state.filters,
  exhausted:   state => state.exhausted,
  isFiltered:  state => (scope, key) => {
    const { scopes: { [scope]: { values: { [key]: { filter = false } = {} } = {} } = {} } = {} } = state
    return filter
  },
  eventsFiltered: state => {
    const fk = Object.keys(state.filters)
    if (fk.length === 0) return state.events
    return state.events.filter(event => {
      const { data: { meta: { timestamp, log_without_prefix, ...meta } = {} } = {} } = event
      for (const k of fk) {
        if (!state.filters[k].includes(meta[k])) return false
      }
      return event
    })
  },
  size: state => state.size,
  lines: state => state.lines,
  options: state => state.options,
  searchQuery: state => state.searchQuery,
  searchIsRegex: state => state.searchIsRegex
}

const addMeta = (scopes, event) => {
  const { data: { meta: { timestamp, log_without_prefix, ...meta } = {} } = {} } = event
  for (const key of Object.keys(meta)) {
    if (!(key in scopes)) {
      Vue.set(scopes[key], 'values', { [meta[key]]: { count: 1 } })
    } else if (!(meta[key] in scopes[key].values)) {
      Vue.set(scopes[key], 'values', {
        ...scopes[key].values,
        [meta[key]]: { count: 1 }
      })
    } else {
      Vue.set(scopes[key].values[meta[key]], 'count', scopes[key].values[meta[key]].count + 1)
    }
  }
}

const actions = {
  setSession: ({ commit, dispatch }, session) => {
    commit('SET_SESSION', session)
    dispatch('loadMore')
  },
  setOptions: ({ commit }, options) => { commit('SET_OPTIONS', options) },
  // Pause/unpause/touch are no-ops here; kept to match the LiveLogs action surface.
  pauseSession: () => {},
  unpauseSession: () => {},
  touchSession: () => {},
  stopSession: ({ commit }) => { commit('SET_RUNNING', false) },
  loadMore: ({ state, commit }) => {
    commit('LOG_SESSION_REQUEST')
    // Collapse per-host cursors into one filename-keyed map; missing entries flag an exhausted peer.
    const cursor = {}
    for (const hostCursor of Object.values(state.cursors)) {
      for (const [file, ms] of Object.entries(hostCursor || {})) {
        if (!(file in cursor) || ms > cursor[file]) cursor[file] = ms
      }
    }
    const body = {
      files: state.session.files,
      filter: state.session.filter || '',
      filter_is_regexp: state.session.filter_is_regexp || false,
      cursor: Object.keys(cursor).length ? cursor : null,
      start: state.session.start,
      end: state.session.end
    }
    return api.query(body).then(response => {
      commit('LOG_SESSION_RESPONSE', response)
      return response
    }).catch(err => {
      commit('LOG_SESSION_ERROR', err.response)
      return err
    })
  },
  toggleFilter: ({ getters, commit }, { scope, key }) => {
    if (getters.isFiltered(scope, key)) commit('LOG_FILTER_DISABLE', { scope, key })
    else commit('LOG_FILTER_ENABLE', { scope, key })
    commit('UPDATE_FILTERS')
  },
  setSize: ({ commit }, size) => commit('UPDATE_SIZE', +size),
  clearEvents: ({ commit }) => { commit('CLEAR_EVENTS') }
}

const mutations = {
  SET_SEARCH_QUERY: (state, q) => { state.searchQuery = q },
  SET_SEARCH_IS_REGEX: (state, b) => { state.searchIsRegex = b },
  SET_SESSION: (state, session) => { state.session = session },
  SET_OPTIONS: (state, options) => { state.options = options },
  SET_RUNNING: (state, v) => { state.running = !!v },
  LOG_SESSION_REQUEST: state => { state.status = 'loading'; state.message = '' },
  LOG_SESSION_RESPONSE: (state, response) => {
    state.status = 'success'
    const { items = [] } = response || {}
    const newEvents = []
    let exhaustedCount = 0
    for (const item of items) {
      const host = item.host
      const peerEvents = item.events || []
      if (peerEvents.length === 0) exhaustedCount++
      // Track per-host so exhausted peers stop driving requests once others fall silent.
      if (item.cursor && Object.keys(item.cursor).length) {
        Vue.set(state.cursors, host, { ...(state.cursors[host] || {}), ...item.cursor })
      }
      for (const ev of peerEvents) newEvents.push(ev)
    }
    if (newEvents.length) {
      newEvents.sort((a, b) => {
        const ta = a.data && a.data.meta && a.data.meta.timestamp || ''
        const tb = b.data && b.data.meta && b.data.meta.timestamp || ''
        return ta < tb ? -1 : ta > tb ? 1 : 0
      })
      state.events = [...state.events, ...newEvents]
      state.lines = state.events.length
      for (const ev of newEvents) addMeta(state.scopes, ev)
    }
    if (items.length > 0 && exhaustedCount === items.length) state.exhausted = true
  },
  LOG_SESSION_ERROR: (state, response) => {
    state.status = 'error'
    if (response && response.data) state.message = response.data.message
  },
  LOG_FILTER_ENABLE: (state, { scope, key }) => {
    Vue.set(state.scopes[scope].values[key], 'filter', true)
  },
  LOG_FILTER_DISABLE: (state, { scope, key }) => {
    Vue.set(state.scopes[scope].values[key], 'filter', false)
  },
  UPDATE_FILTERS: state => {
    const filters = {}
    for (const [scope, { values = {} }] of Object.entries(state.scopes)) {
      const active = Object.entries(values).filter(([, v]) => v.filter).map(([k]) => k)
      if (active.length) filters[scope] = active
    }
    state.filters = filters
  },
  UPDATE_SIZE: (state, size) => { state.size = size },
  CLEAR_EVENTS: state => {
    state.events = []
    state.lines = 0
    for (const scope of Object.keys(state.scopes)) {
      Vue.set(state.scopes[scope], 'values', {})
    }
    state.cursors = {}
    state.exhausted = false
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
