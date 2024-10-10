import Vue from 'vue'
import { computed } from '@vue/composition-api'
import Loading from 'vue-loading-overlay'
import 'vue-loading-overlay/dist/vue-loading.css'
import Router from 'vue-router'
import store from '@/store'
import axios from 'axios'

import LoginRoute from '@/views/Login/_router'
import StatusRoute from '@/views/Status/_router'
import ReportsRoute from '@/views/Reports/_router'
import AuditingRoute from '@/views/Auditing/_router'
import NodesRoute from '@/views/Nodes/_router'
import UsersRoute from '@/views/Users/_router'
import ConfigurationRoute from '@/views/Configuration/_router'
import ConfiguratorRoute from '@/views/Configurator/_router'
import PreferencesRoute from '@/views/Preferences/_router'
import ResetRoute from '@/views/Reset/_router'

Vue.use(Loading)

let loader = null
const hideLoader = () => {
  if (loader) {
    loader.hide()
  }
}
const showLoader = () => {
  hideLoader()
  loader = Vue.$loading.show({
    loader: 'dots',
    color: 'var(--primary)',
    width: 64,
    height: 64,
    opacity: 0.5
  })
}

Vue.use(Router)

const DefaultRoute = {
  path: '*',
  name: 'default',
  component: {
    render: () => { /* noop */ },
    name: 'default',
  },
  beforeEnter: (to, from, next) => {
    store.dispatch('system/getSummary').then(() => { // wait for summary
      next({ path: '/status' }) // graceful redirect
    })
  }
}

let router = new Router({
  routes: [
    LoginRoute,
    StatusRoute,
    ReportsRoute,
    AuditingRoute,
    NodesRoute,
    UsersRoute,
    ConfigurationRoute,
    ConfiguratorRoute,
    PreferencesRoute,
    ResetRoute,
    DefaultRoute
  ]
})

router.beforeEach((to, from, next) => {
  if (to.path && !['/', '/login', '/logout', '/expire'].includes(to.path)) {
    showLoader()
  }
  /**
  * 1. Check if a matching route defines a transition delay
  * 2. Hide the document scrollbar during the transition (see bootstrap/scss/_modal.scss)
  */
  let transitionDelay = from.matched.find(route => {
    return route.meta.transitionDelay // [1]
  })
  if (transitionDelay) {
    document.body.classList.add('modal-open') // [2]
  }
  /**
   * 3. Ignore everything under /configurator-
   * 4. Ignore login page
   * 5. Session token loaded from local storage
   * 6. Configurator is enabled -- go to configurator
   * 7. Token has expired -- go back to login page
   * 8. No token -- go back to login page
   */
  if (/^configurator-/.test(to.name)) { // [3]
    store.commit('session/CONFIGURATOR_ACTIVE')
    next()
  } else {
    store.commit('session/CONFIGURATOR_INACTIVE')
    if (to.name !== 'login') { // [4]
      store.dispatch('session/load').then(() => {
        next() // [5]
      }).catch(() => {
        let currentPath = router.currentRoute.fullPath
        if (currentPath === '/') {
          currentPath = document.location.hash.substring(1)
        }
        axios.get('/api/v1/configurator/config/system/hostname').then(() => {
          next({ name: 'configurator' }) // [6]
        }).catch(() => {
          if (store.state.session.token) {
            next({ name: 'login', params: { expire: true, previousPath: currentPath } }) // [7]
          } else {
            next({ name: 'login' }) // [8]
          }
        })
      })
    } else {
      next()
    }
  }
})

router.afterEach((to, from) => {
  routeData.params = to.params
  routeData.query = to.query
  /**
  * 1. Check if a matching route defines a transition delay
  * 2. Restore the document scrollbar after the transition delay
  * 3. Scroll to top of the page
  */
  let transitionDelay = from.matched.find(route => {
    return route.meta.transitionDelay // [1]
  })
  setTimeout(() => {
    document.body.classList.remove('modal-open') // [2]
    window.scrollTo(0, 0) // [3]
    hideLoader()
  }, transitionDelay || 300)
  /**
   * Fetch data required for ALL authenticated pages
   */
  if (store.state.session.username) {
    if (store.state.system.summary === false) {
      store.dispatch('system/getSummary')
    }
  }
  store.dispatch('analytics/trackRoute', { to, from })
})

export default router

const routeData = Vue.observable({ params: {}, query: {} })
export const useParams = () => computed(() => routeData.params)
export const useQuery = () => computed(() => routeData.query)
