import { reset as resetVuexStore } from '@/store'
import LoginView from '../'

const route = {
  path: '/login',
  alias: ['/logout', '/expire'],
  name: 'login',
  component: LoginView,
  beforeEnter: (to, from, next) => {
    resetVuexStore()
    next()
  }
}

export default route
