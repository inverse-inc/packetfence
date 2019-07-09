import Vue from 'vue'
import Vuex from 'vuex'
import config from './modules/config'
import events from './modules/events'
import documentation from './modules/documentation'
import notification from './modules/notification'
import performance from './modules/performance'
import pfqueue from './modules/pfqueue'
import preferences from './modules/preferences'
import saveSearch from './modules/saveSearch'
import services from './modules/services'
import session from './modules/session'
import system from './modules/system'

Vue.use(Vuex)

const debug = process.env.NODE_ENV !== 'production'

export const types = {
  LOADING: 'loading',
  SUCCESS: 'success',
  ERROR: 'error'
}

export default new Vuex.Store({
  // actions,
  modules: {
    config,
    events,
    documentation,
    notification,
    performance,
    pfqueue,
    preferences,
    saveSearch,
    services,
    session,
    system
  },
  strict: debug
})
