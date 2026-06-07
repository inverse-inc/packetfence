import store from '@/store'
import StoreModule from './_store'

const TheView = () => import(/* webpackChunkName: "Auditing" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_pftest) {
    store.registerModule('$_pftest', StoreModule)
  }
  next()
}

export default [
  {
    path: 'pftest',
    name: 'pftest',
    component: TheView,
    meta: { can: 'read services' },
    beforeEnter
  }
]
