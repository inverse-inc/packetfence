import Vue from 'vue'
import Vuex from 'vuex'
import config from './modules/config'
import notification from './modules/notification'
import pfqueue from './modules/pfqueue'
import preferences from './modules/preferences'
import saveSearch from './modules/saveSearch'
import services from './modules/services'
import session from './modules/session'
import system from './modules/system'

Vue.use(Vuex)

const debug = process.env.NODE_ENV !== 'production'

export default new Vuex.Store({
  // actions,
  modules: {
    config,
    notification,
    pfqueue,
    preferences,
    saveSearch,
    services,
    session,
    system
  },
  strict: debug
})
