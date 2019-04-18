import Vue from 'vue'
import Vuex from 'vuex'
import config from './modules/config'
import notification from './modules/notification'
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
    services,
    session,
    system
  },
  strict: debug
})
