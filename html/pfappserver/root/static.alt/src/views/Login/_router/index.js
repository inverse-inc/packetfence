import store from '@/store'
import LoginStore from '../_store'
import LoginView from '../'

const route = {
  path: '/login',
  alias: ['/logout', '/expire'],
  name: 'login',
  component: LoginView,
  beforeEnter: (to, from, next) => {
    // Register store module only once
    if (!store.state.$_auth) {
      store.registerModule('$_auth', LoginStore)
    }
    next()
  }
}

export default route
