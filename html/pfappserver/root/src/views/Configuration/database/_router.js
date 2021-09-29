import store from '@/store'
import BasesStoreModule from '../bases/_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/TheTabsDatabase')

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
    props: () => ({ tab: 'database_general' }),
    beforeEnter
  },
  {
    path: 'database_advanced',
    name: 'database_advanced',
    component: TheTabs,
    props: () => ({ tab: 'database_advanced' }),
    beforeEnter
  }
]
