import store from '@/store'
import BasesStoreModule from '../_store/bases'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/DatabaseTabs')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_bases) {
    store.registerModule('$_bases', BasesStoreModule)
  }
  next()
}

export default [
  {
    path: 'database_general',
    name: 'database_general',
    component: TheTabs,
    props: (route) => ({ tab: 'database_general', query: route.query.query }),
    beforeEnter
  },
  {
    path: 'database_advanced',
    name: 'database_advanced',
    component: TheTabs,
    props: (route) => ({ tab: 'database_advanced', query: route.query.query }),
    beforeEnter
  }
]
