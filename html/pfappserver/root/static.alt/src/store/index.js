import Vue from 'vue'
import Vuex from 'vuex'
import notification from './modules/notification'
import session from './modules/session'
import config from './modules/config'

Vue.use(Vuex)

const debug = process.env.NODE_ENV !== 'production'

export default new Vuex.Store({
  // actions,
  modules: {
    notification,
    session,
    config
  },
  strict: debug
})
