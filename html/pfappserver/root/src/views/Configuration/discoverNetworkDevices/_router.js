import acl from '@/utils/acl'
import store from '@/store'
import StoreModule from './_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/TheTabsNetworkDevices')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'discover_network_devices' })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_discover_network_devices)
    store.registerModule('$_discover_network_devices', StoreModule)
  next()
}

const can = () => acl.$can('read', 'system')

export default [
  {
    path: 'discover_network_devices',
    name: 'discover_network_devices',
    component: TheTabs,
    meta: {
      can
    },
    props: () => ({ tab: 'discover_network_devices' }),
    beforeEnter
  }
]
