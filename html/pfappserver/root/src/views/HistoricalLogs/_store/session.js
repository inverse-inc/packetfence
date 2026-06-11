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
import { defaultScopes, addMeta, isFilteredGetter, eventsFilteredGetter, computeFilters } from '@/utils/logEvents'

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
  cursors: {}, // { hostA: { 'packetfence.log': {source, offset, sig, ...} }, hostB: {...} }
  options: { background: 'white', size: 'normal', order: 'forward', output: 'color' },
  events: [],
  filters: {},
  scopes: defaultScopes(),
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
  message:     state => state.message,
  isFiltered:  isFilteredGetter,
  eventsFiltered: eventsFilteredGetter,
  size: state => state.size,
  lines: state => state.lines,
  options: state => state.options,
  searchQuery: state => state.searchQuery,
  searchIsRegex: state => state.searchIsRegex
}

// Cluster peers reachable via the X-PacketFence-Server header (same list
// the LiveLogs sessions fan out over).
const peerList = () => {
  const servers = store.state.cluster && store.state.cluster.servers
  if (!servers) return []
  return Object.values(servers).filter(s => s && s.management_ip)
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
    const baseBody = {
      files: state.session.files,
      filter: state.session.filter || '',
      filter_is_regexp: state.session.filter_is_regexp || false,
      start: state.session.start,
      end: state.session.end
    }
    // One request per cluster peer (X-PacketFence-Server routing) — each
    // peer gets its own cursor map back verbatim: cursors are opaque
    // byte-position objects scoped to that node's files, never merged or
    // shared across hosts.
    const isCluster = store.getters['cluster/isCluster']
    const peers = isCluster ? peerList() : [null]
    return Promise.all(peers.map(peer => {
      const host = peer ? peer.host : 'localhost'
      const hostCursor = state.cursors[host]
      const body = {
        ...baseBody,
        cursor: hostCursor && Object.keys(hostCursor).length ? hostCursor : null
      }
      return api.query(body, peer || undefined)
        .then(response => ({ host, ...response }))
        .catch(err => {
          const { response: { data: { message = i18n.t('Request failed') } = {} } = {} } = err
          return { host, error: message, events: [], cursor: null, truncated: false }
        })
    })).then(items => {
      commit('LOG_SESSION_RESPONSE', { items })
      return items
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
    // Items are assembled client-side, one per peer: {host, events, cursor,
    // truncated, [error]}. The host tag comes from the peer list, not the
    // response body.
    const { items = [] } = response || {}
    const newEvents = []
    let exhaustedCount = 0
    let firstError = ''
    for (const item of items) {
      const host = item.host
      const peerEvents = item.events || []
      if (item.error) {
        // A failed peer is not "exhausted" — keep Load more available so a
        // transient error does not end the pagination.
        firstError = firstError || `${host}: ${item.error}`
      } else if (peerEvents.length === 0 && !item.truncated) {
        // A truncated empty page just means the scan budget expired before
        // a match was found — the cursor advanced, there may be more.
        exhaustedCount++
      }
      // Track per-host: cursors are opaque per-node objects, replayed verbatim.
      if (item.cursor && Object.keys(item.cursor).length) {
        Vue.set(state.cursors, host, { ...(state.cursors[host] || {}), ...item.cursor })
      }
      for (const ev of peerEvents) newEvents.push(ev)
    }
    state.message = firstError
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
    if (items.length > 0 && !firstError && exhaustedCount === items.length) state.exhausted = true
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
    state.filters = computeFilters(state.scopes)
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
