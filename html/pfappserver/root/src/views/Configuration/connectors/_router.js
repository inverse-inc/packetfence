import store from '@/store'
import StoreModule from './_store'

const TheSearch = () => import(/* webpackChunkName: "ConfigurationSystem" */ './connectors/_components/TheSearch')
import ConnectorsRoutes from './connectors/_router'

export const beforeEnter = (to, from, next = () => { }) => {
  if (!store.state.$_connectors)
    store.registerModule('$_connectors', StoreModule)
  next()
}

export default [
  // The connectors list is the section: DNS servers and domains live on each
  // connector, so there is nothing else to tab between.
  {
    path: 'connectors',
    name: 'connectors',
    component: TheSearch,
    beforeEnter
  },
  ...ConnectorsRoutes
]
