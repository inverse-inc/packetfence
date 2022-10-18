/**
* "analytics" store module
*/
import mixpanel from 'mixpanel-browser'
import store from '@/store'
import i18n from '@/utils/locale'

// Default values
const initialState = () => {
  return {
    initialized: false,
    route: {},
    summary: {},
    unsubscribe: () => {},
  }
}

const getters = {
  route: state => state.route
}

const actions = {
  init: ({ commit, getters, state }) => {
    let promise = new Promise(r => r())
    if (!state.initialized) {
      commit('INIT')
      commit('UNSUBSCRIBE')
      promise = store.dispatch('system/getSummary').then(summary => {
        const {
          hostname, // strip PII
          quiet, status, // strip noise
          send_anonymous_stats = false, // track?
          ...summaryNoPii // safe to xfer
        } = summary
        commit('SUMMARY', summaryNoPii)
        if (send_anonymous_stats) {
          mixpanel.init('7061636B657466656E63652E6F72672F', {
            api_host:               'https://analytics.packetfence.org',
            app_host:               'https://app-analytics.packetfence.org',
            cdn:                    'https://cdn-analytics.packetfence.org',
            cross_subdomain_cookie: true,
            persistence:            'cookie',
            persistence_name:       '',
            cookie_name:            '',
            store_google:           true,
            save_referrer:          true,
            test:                   false,
            verbose:                false,
            img:                    false,
            track_pageview:         true,
            track_links_timeout:    300,
            cookie_expiration:      365,
            upgrade:                false,
            disable_persistence:    false,
            disable_cookie:         false,
            secure_cookie:          false,
            ip:                     false,
            property_blacklist:     [],
            ignore_dnt:             true,
            debug:                  false,
            loaded: () => {
              const unsubscribe = store.subscribeAction((storeAction, storeState) => {
                const { type, payload } = storeAction
                const isCollection = type => /^\$_/.test(type) // $_ prefix
                const isCluster = type => /^cluster\//.test(type) // ^cluster/
                const isGetter = type => /\/get/.test(type) || /\/all/.test(type) || /\/files$/.test(type) // /get... || /all... || /files$
                const isIgnore = type => /^\$_status/.test(type) || /^\$_network_threats/.test(type) // $_status/*, $_network_threats/*
                const isOptions = type => /\/options/.test(type) // /options, /optionsBy...
                const isTracked = type => (isCollection(type) || isCluster(type)) && !(isGetter(type) || isOptions(type) || isIgnore(type))
                if (isTracked(type)) {
                  const matches = type.match(/^(\$_)?([a-zA-Z0-9_]+)\/([a-zA-Z0-9]+)/)
                  if (matches) {
                    // eslint-disable-next-line no-unused-vars
                    const [_type, _prefix, module, action] = matches
                    const event = `${module}/${action}`
                    const { [`$_${module}`]: { analytics: { track = [] } = {} } = {} } = storeState
                    const trackNoPii = Object.entries(payload) // unpack
                      .filter(([k]) => track.includes(k)) // only tracked
                      .reduce((types, [k, v]) => ({ ...types, [k]: v }), {}) // repack
                    mixpanel.track(event, { event, module, action, ...getters.route, ...summaryNoPii, ...trackNoPii, locale: i18n.locale })
                  }
                }
              })
              commit('SUBSCRIBED', unsubscribe)
              const { os, version } = summaryNoPii
              // prefix _ avoids collision
              mixpanel.set_group('_os', os)
              mixpanel.set_group('_version', version)
              mixpanel.set_group('_language', navigator.languages)
            }
          })
        }
      })
    }
    return promise
  },
  trackEvent: ({ dispatch, getters, state }, event) => {
    const [eventName, eventData] = event
    return dispatch('init').then(() => mixpanel.track(eventName, { ...eventData, ...getters.route, ...state.summary, locale: i18n.locale }))
  },
  trackRoute: ({ commit, dispatch, getters, state }, route) => {
    return dispatch('init')
      .then(() => {
        commit('ROUTE', route)
        return mixpanel.track('route', { ...getters.route, ...state.summary, locale: i18n.locale })
      })
  }
}

const mutations = {
  INIT: (state) => {
    state.initialized = true
  },
  ROUTE: (state, route) => {
    const { to, from } = route
    let clean = {}
    if (from.name) {
      clean.fromName = from.name
    }
    if (from.fullPath) {
      const { params: fromParams, matched: fromMatched = [], meta: { track: fromTrack = [] } = {} } = from
      // strip user-defined dynamic variables (/:id, /:mac)
      const { [fromMatched.length - 1]: { path: fromPath = from.fullPath } = {} } = fromMatched
      clean.fromUrl = fromPath.replace(/\(.*\)$/, '') // remove regex
      if (fromTrack.length) { // track parameters
        for (let param of fromTrack) {
          clean[`from${param}`] = fromParams[param] || null
        }
      }
    }
    if (to.name) {
      clean.toName = to.name
    }
    if (to.fullPath) {
      const { params: toParams, matched: toMatched = [], meta: { track: toTrack = [] } = {} } = to
      // strip user-defined dynamic variables (/:id, /:mac)
      const { [toMatched.length - 1]: { path: toPath = to.fullPath } = {} } = toMatched
      clean.toUrl = toPath.replace(/\(.*\)$/, '') // remove regex
      if (toTrack.length) { // track parameters
        for (let param of toTrack) {
          clean[`to${param}`] = toParams[param] || null
        }
      }
    }
    state.route = clean
 },
  SUMMARY: (state, summary) => {
    state.summary = summary
  },
  SUBSCRIBED: (state, unsubscribe) => {
    state.unsubscribe = unsubscribe
  },
  UNSUBSCRIBE: (state) => {
    state.unsubscribe()
  },
  $RESET: (state) => {
    state.unsubscribe()
    // eslint-disable-next-line no-unused-vars
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