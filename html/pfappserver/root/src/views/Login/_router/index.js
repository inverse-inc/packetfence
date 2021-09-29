import { reset as resetVuexStore } from '@/store'
import TheView from '../'

const route = {
  path: '/login',
  alias: ['/logout', '/expire'],
  name: 'login',
  component: TheView,
  beforeEnter: (to, from, next) => {
    resetVuexStore()
    next()
  }
}

export default route
