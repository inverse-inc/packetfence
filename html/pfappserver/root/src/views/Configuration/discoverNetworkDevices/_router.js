import acl from '@/utils/acl'
import store from '@/store'
import StoreModule from './_store'
import SwitchesStoreModule from '../switches/_store'
import SwitchGroupsStoreModule from '../switchGroups/_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/TheTabsNetworkDevices')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'discover_network_devices' })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_discover_network_devices)
    store.registerModule('$_discover_network_devices', StoreModule)
  if (!store.state.$_switches)
    store.registerModule('$_switches', SwitchesStoreModule)
  if (!store.state.$_switch_groups)
    store.registerModule('$_switch_groups', SwitchGroupsStoreModule)
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
