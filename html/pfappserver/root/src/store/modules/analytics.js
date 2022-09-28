/**
* "analytics" store module
*/
import store from '@/store'
import { insertScript } from '@/utils/dom'

const getTracker = () => window.Piwik.getAsyncTracker()

/*
export function getResolvedHref (router, path) {
  return router.resolve(path).href
}
*/

// Default values
const initialState = () => {
  return {
    initialized: false,
  }
}

const getters = {}

/*
import VueMatomo from 'vue-matomo'
Vue.use(VueMatomo, {
  host: 'https://172.105.97.18',
  siteId: 2,
  router,
  debug: process.env.VUE_APP_DEBUG === 'true',
  enableHeartBeatTimer: true,
  trackSiteSearch: to => {
    const { meta: { track = true } = {} } = to
    return track
  }
})

*/

const TRACKER_HOST = 'https://172.105.97.18'
const TRACKER_SCRIPT = `${TRACKER_HOST}/matomo.js`
const TRACKER_ENDPOINT = `${TRACKER_HOST}/matomo.php`

const actions = {
  init: ({ commit, state }) => {
    let promise = new Promise(r => r())
    if (!state.initialized) {
      commit('INIT')
      promise = store.dispatch('system/getSummary').then(summary => {
        const { version, analytics = true } = summary
        if (analytics) {
          // eslint-disable-next-line no-unused-vars
          const [full, majorVersion, minorVersion] = version.match(/(\d+).(\d+).\d+/)
          const siteId = parseInt(majorVersion) << 16 | parseInt(minorVersion) << 8
          window._paq = window._paq || []
          window._paq.push(['setTrackerUrl', TRACKER_ENDPOINT])
          window._paq.push(['setSiteId', siteId])
          window._paq.push(['enableHeartBeatTimer', 15])
          // insert script if not exists
          if (Array.prototype.slice.call(document.getElementsByTagName('script')).filter(script => script.src === TRACKER_SCRIPT).length === 0) {
            const crossOrigin = undefined
            return insertScript(TRACKER_SCRIPT, crossOrigin)
          }
        }
      })
    }
    return promise
  },
  trackEvent: ({ dispatch }, params) => {
    dispatch('init')
      .then(() => {
        const [category, action, name, value] = params
        const tracker = getTracker()
        return tracker.trackEvent(category, action, name, value)
      })
  },
  trackRoute: ({ dispatch }, route) => {
    dispatch('init')
      .then(() => {
        const tracker = getTracker()
        const { to, from } = route
        if (from.fullPath) {
          // strip user-defined dynamic variables
          const { matched: fromMatched = [] } = from
          const { [fromMatched.length - 1]: { path: fromPath } = {} } = fromMatched
          tracker.setReferrerUrl(window.location.origin + fromPath)
        }
        if (to.fullPath) {
          // strip user-defined dynamic variables
          const { matched: toMatched = [] } = to
          const { [toMatched.length - 1]: { path: toPath } = {} } = toMatched
          tracker.setCustomUrl(window.location.origin + toPath)
        }
        return tracker.trackPageView(to.name)
      })
  }
}

const mutations = {
  INIT: (state) => {
    state.initialized = true
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