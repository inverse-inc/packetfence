import store from '@/store'
import BasesStoreModule from '../_store/bases'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/MainTabs')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_bases) {
    store.registerModule('$_bases', BasesStoreModule)
  }
  next()
}

export default [
  {
    path: 'services',
    name: 'services',
    component: TheTabs,
    props: (route) => ({ tab: 'services', query: route.query.query }),
    beforeEnter
  }
]
