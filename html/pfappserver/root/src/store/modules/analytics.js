/**
* "analytics" store module
*/
import mixpanel from 'mixpanel-browser'
import store from '@/store'

const xlatEvent = event => {
  const xlat = {
    '0': 'Zero',
    '1': 'One',
    '2': 'Two',
    '3': 'Three',
    '4': 'Four',
    '5': 'Five',
    '6': 'Six',
    '7': 'Seven',
    '8': 'Eight',
    '9': 'Nine'
  }
  for (let i = 0; i < event.length; i++) {
    if (event[i] in xlat) {
      event[i] = xlat[event[i]]
    }
  }
  return event
}

// Default values
const initialState = () => {
  return {
    initialized: false,
    summary: {},
    unsubscribe: () => {},
  }
}

const getters = {}

const actions = {
  init: ({ commit, state }) => {
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
            ip:                     true,
            property_blacklist:     [],
            ignore_dnt:             true,
            debug:                  process.env.VUE_APP_DEBUG === 'true',
            loaded: () => {
              const unsubscribe = store.subscribeAction((storeAction, state) => {
                const { type } = storeAction
                const isCollection = type => /^\$_/.test(type) // $_ prefix
                const isCluster = type => /^cluster\//.test(type) // ^cluster/
                const isGetter = type => /\/get/.test(type) // /get
                const isOptions = type => /\/options$/.test(type) // /options$
                const isTracked = type => (isCollection(type) || isCluster(type)) && !(isGetter(type) || isOptions(type))
                if (isTracked(type)) {
                  const matches = type.match(/^(\$_)?([a-zA-Z]+)\/([a-zA-Z]+)/)
                  if (matches) {
                    // eslint-disable-next-line no-unused-vars
                    const [_type, _prefix, event, action] = matches
                    mixpanel.track(xlatEvent(`${event}/${action}`), { ...state.summary, event, action })
                  }
                }
              })
              commit('SUBSCRIBED', unsubscribe)
            }
          })
        }
      })
    }
    return promise
  },
  trackRoute: ({ dispatch, state }, route) => {
    return dispatch('init')
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