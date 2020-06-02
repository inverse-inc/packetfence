import { reset as resetStore } from '@/store'
import ResetView from '../'

const route = {
  path: '/reset',
  name: 'reset',
  component: ResetView,
  beforeEnter: (to, from, next) => {
    resetStore()
    next()
  }
}

export default route

