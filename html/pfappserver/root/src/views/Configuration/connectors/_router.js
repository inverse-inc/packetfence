import store from '@/store'
import StoreModule from './_store'

const TheTabs = () => import(/* webpackChunkName: "ConfigurationSystem" */ '../_components/TheTabsConnectors')
import ConnectorsRoutes from './connectors/_router'
import ConnectorsDnsRoutes from './dns/_router'
import ConnectorsDomainsRoutes from './domains/_router'

export const beforeEnter = (to, from, next = () => { }) => {
  if (!store.state.$_connectors)
    store.registerModule('$_connectors', StoreModule)
  next()
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
