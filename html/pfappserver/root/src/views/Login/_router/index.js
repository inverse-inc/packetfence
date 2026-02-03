import { reset as resetVuexStore } from '@/store'
import TheView from '../'

const route = {
  path: '/login',
  alias: ['/logout', '/expire'],
  name: 'login',
  component: TheView,
  beforeEnter: (to, from, next) => {
    if (from.fullPath && !['/', '/login', '/logout', '/expire'].includes(from.path)) {
      localStorage.setItem('last_uri', from.fullPath)
    }
    resetVuexStore()
    next()
  }
}

export default route
