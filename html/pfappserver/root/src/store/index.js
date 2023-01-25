import Vue from 'vue'
import Vuex from 'vuex'
import analytics from './modules/analytics'
import config from './modules/config'
import cluster from './modules/cluster'
import documentation from './modules/documentation'
import k8s from './modules/k8s'
import lookup from './modules/lookup'
import notification from './modules/notification'
import performance from './modules/performance'
import pfqueue from './modules/pfqueue'
import preferences from './modules/preferences'
import radius from './modules/radius'
import session from './modules/session'
import system from './modules/system'

Vue.use(Vuex)

const debug = process.env.VUE_APP_DEBUG === 'true'
Vue.config.devtools = debug

export const types = {
  DELETING:     'deleting',
  DISABLING:    'disabling',
  DRYRUN:       'dryrun',
  ENABLING:     'enabling',
  ERROR:        'error',
  INITIALIZING: 'initializing',
  LOADING:      'loading',
  READING:      'reading',
  REASSIGNING:  'reassigning',
  RESTARTING:   'restarting',
  STARTING:     'starting',
  STOPPING:     'stopping',
  SUCCESS:      'success',
  WRITING:      'writing',
}

const store = new Vuex.Store({
  modules: {
    analytics,
    config,
    cluster,
    documentation,
    k8s,
    lookup,
    notification,
    performance,
    pfqueue,
    preferences,
    radius,
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
