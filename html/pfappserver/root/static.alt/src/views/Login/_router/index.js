import store from '@/store'
import LoginView from '../'

const route = {
  path: '/login',
  alias: ['/logout', '/expire'],
  name: 'login',
  component: LoginView,
  beforeEnter: (to, from, next) => {
    // Reset states and unregister temporary modules
    Object.keys(store._modules.root._children).forEach(module => {
      if (module[0] === '$' && module[1] === '_') {
        store.unregisterModule(module)
      } else {
        store.commit(`${module}/$RESET`, null, { root: true })
      }
    })
    next()
  }
}

export default route
