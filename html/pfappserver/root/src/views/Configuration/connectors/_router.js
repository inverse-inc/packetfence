import store from '@/store'
import StoreModule from './_store'
import FingerbankStoreModule from '../fingerbank/_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/TheTabsConnectors')
import ConnectorsRoutes from './connectors/_router'
import ConnectorsDnsRoutes from './dns/_router'
import ConnectorsDomainsRoutes from './domains/_router'

export const beforeEnter = (to, from, next = () => { }) => {
  if (!store.state.$_connectors)
    store.registerModule('$_connectors', StoreModule)
  if (!store.state.$_fingerbank)
    store.registerModule('$_fingerbank', FingerbankStoreModule)
  store.dispatch('$_fingerbank/getGeneralSettings').then(() => {
    next()
  })
}

export default [
  {
    path: 'connectors',
    name: 'connectors',
    component: TheTabs,
    props: () => ({ tab: 'connectorsConnectors' }),
    beforeEnter
  },
  ...ConnectorsRoutes,
  ...ConnectorsDnsRoutes,
  ...ConnectorsDomainsRoutes
]
