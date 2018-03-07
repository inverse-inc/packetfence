import Vue from 'vue'
import Router from 'vue-router'

import LoginRoute from '@/views/Login/_router'
import StatusRoute from '@/views/Status/_router'
import NodesRoute from '@/views/Nodes/_router'
import UsersRoute from '@/views/Users/_router'

Vue.use(Router)

export default new Router({
  routes: [
    LoginRoute,
    StatusRoute,
    NodesRoute,
    UsersRoute
  ]
})
