import store from '@/store'
import { onPremOnly } from '@/utils/router'
import BasesStoreModule from '../bases/_store'

const TheTabs = () => import(/* webpackChunkName: "ConfigurationSystem" */ '../_components/TheTabsDatabase')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_bases) {
    store.registerModule('$_bases', BasesStoreModule)
  }
  next()
}

// Advanced and ProxySQL do not apply in cloud and are hidden there
// (see TheTabsDatabase); send anyone reaching them by URL back to General.
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
    beforeEnter: onPremOnly(beforeEnter, 'database_general')
  },
  {
    path: 'database_proxysql',
    name: 'database_proxysql',
    component: TheTabs,
    props: () => ({ tab: 'database_proxysql' }),
    beforeEnter: onPremOnly(beforeEnter, 'database_general')
  }
]
