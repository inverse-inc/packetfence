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
          analytics = true, // track?
          ...summaryNoPii // safe to xfer
        } = summary
        commit('SUMMARY', summaryNoPii)
        if (analytics) {
          mixpanel.init(process.env.VUE_APP_MIXPANEL_TOKEN, {
            api_host:               'https://api.mixpanel.com',
            app_host:               'https://mixpanel.com',
            cdn:                    'https://cdn.mxpnl.com',
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
            debug:                  false, // process.env.VUE_APP_DEBUG === 'true',
            loaded: () => {
              const unsubscribe = store.subscribeAction(storeAction => {
                const { type } = storeAction
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
                    mixpanel.track(event, { event, module, action, ...getters.route, ...summaryNoPii, locale: i18n.locale })
                  }
                }
              })
              commit('SUBSCRIBED', unsubscribe)
              const { version } = summaryNoPii
              // prefix _ avoids collision
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
      const { matched: fromMatched = [], meta: { track: fromTrack } = {}, path: fromRawPath } = from
      if (fromTrack) {
        clean.fromUrl = decodeURIComponent(fromRawPath)
      }
      else {
        // strip user-defined dynamic variables (/:id, /:mac)
        const { [fromMatched.length - 1]: { path: fromPath = from.fullPath } = {} } = fromMatched
        clean.fromUrl = fromPath.replace(/\(.*\)$/, '') // remove regex
      }
    }
    if (to.name) {
      clean.toName = to.name
    }
    if (to.fullPath) {
      const { matched: toMatched = [], meta: { track: toTrack } = {}, path: toRawPath } = to
      if (toTrack) { // track identifiers
        clean.toUrl = decodeURIComponent(toRawPath)
      }
      else {
        // strip user-defined dynamic variables (/:id, /:mac)
        const { [toMatched.length - 1]: { path: toPath = to.fullPath } = {} } = toMatched
        clean.toUrl = toPath.replace(/\(.*\)$/, '') // remove regex
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