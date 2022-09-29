/**
* "analytics" store module
*/
import mixpanel from 'mixpanel-browser'
import store from '@/store'

// Default values
const initialState = () => {
  return {
    initialized: false,
    summary: {},
  }
}

const getters = {}

const actions = {
  init: ({ commit, state }) => {
    let promise = new Promise(r => r())
    if (!state.initialized) {
      commit('INIT')
      promise = store.dispatch('system/getSummary').then(summary => {
        // eslint-disable-next-line no-unused-vars
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
            ip:                     true,
            property_blacklist:     [],
            ignore_dnt:             true,
            debug:                  process.env.VUE_APP_DEBUG === 'true',
            loaded:                 () => {}
          })
        }
      })
    }
    return promise
  },
  trackEvent: ({ dispatch, state }, params) => {
    dispatch('init')
      .then(() => {
        const [category, action, toUrl] = params
        return mixpanel.track(category, { ...state.summary, action, toUrl })
      })
  },
  trackRoute: ({ dispatch, state }, route) => {
    dispatch('init')
      .then(() => {
        const { to, from } = route
        let event = {}
        if (from.name) {
          event.fromName = from.name
        }
        if (from.fullPath) {
          // strip user-defined dynamic variables
          const { matched: fromMatched = [] } = from
          const { [fromMatched.length - 1]: { path: fromPath = from.fullPath } = {} } = fromMatched
          event.fromUrl = fromPath
        }
        if (to.name) {
          event.toName = to.name
        }
        if (to.fullPath) {
          // strip user-defined dynamic variables
          const { matched: toMatched = [] } = to
          const { [toMatched.length - 1]: { path: toPath = to.fullPath } = {} } = toMatched
          event.toUrl = toPath
        }
        return mixpanel.track('route', { ...state.summary, ...event })
      })
  }
}

const mutations = {
  INIT: (state) => {
    state.initialized = true
  },
  SUMMARY: (state, summary) => {
    state.summary = summary
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