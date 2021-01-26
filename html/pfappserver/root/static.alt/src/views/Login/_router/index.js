import { reset as resetStore } from '@/store'
import LoginView from '../'

const route = {
  path: '/login',
  alias: ['/logout', '/expire'],
  name: 'login',
  component: LoginView,
  beforeEnter: (to, from, next) => {
    resetStore()
    next()
  }
}

export default route
