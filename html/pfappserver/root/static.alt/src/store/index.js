import Vue from 'vue'
import Vuex from 'vuex'
import config from './modules/config'
import documentation from './modules/documentation'
import events from './modules/events'
import lookup from './modules/lookup'
import notification from './modules/notification'
import performance from './modules/performance'
import pfqueue from './modules/pfqueue'
import preferences from './modules/preferences'
import radius from './modules/radius'
import saveSearch from './modules/saveSearch'
import services from './modules/services'
import session from './modules/session'
import system from './modules/system'

const debug = process.env.VUE_APP_DEBUG === 'true'
Vue.config.devtools = debug

export const types = {
  LOADING: 'loading',
  SUCCESS: 'success',
  ERROR: 'error'
}

const store = Vuex.createStore({
  modules: {
    config,
    documentation,
    events,
    lookup,
    notification,
    performance,
    pfqueue,
    preferences,
    radius,
    saveSearch,
    services,
    session,
    system
  },
  strict: debug
})

export const reset = () => {
  // Reset states and unregister temporary modules
  Object.keys(store._modules.root._children).forEach(module => {
    if (module[0] === '$' && module[1] === '_') {
      store.unregisterModule(module)
    } else {
      store.commit(`${module}/$RESET`, null, { root: true })
    }
  })
}

export default store
