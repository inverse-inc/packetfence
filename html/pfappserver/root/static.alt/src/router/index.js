import Vue from 'vue'
import Router from 'vue-router'

import LoginRoute from '@/views/Login/_router'
import StatusRoute from '@/views/Status/_router'
import NodesRoute from '@/views/Nodes/_router'
import UsersRoute from '@/views/Users/_router'

Vue.use(Router)

let router = new Router({
  routes: [
    LoginRoute,
    StatusRoute,
    NodesRoute,
    UsersRoute
  ]
})

router.beforeEach((to, from, next) => {
  /**
    * 1. Check if a matching route defines a transition delay
    * 2. Hide the document scrollbar during the transition
    */
  let transitionRoute = from.matched.find(route => {
    return route.meta.transitionDelay // [1]
  })
  if (transitionRoute) {
    document.body.classList.add('modal-open') // [2]
  }
  next()
})

router.afterEach((to, from) => {
  /**
    * 1. Check if a matching route defines a transition delay
    * 2. Restore the document scrollbar after the transition delay
    */
  let transitionRoute = from.matched.find(route => {
    return route.meta.transitionDelay // [1]
  })
  if (transitionRoute) {
    setTimeout(() => {
      document.body.classList.remove('modal-open') // [2]
    }, transitionRoute.meta.transitionDelay)
  }
})

export default router
