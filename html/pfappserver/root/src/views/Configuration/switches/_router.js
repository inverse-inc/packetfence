import store from '@/store'
import RolesStoreModule from '../roles/_store'
import SwitchesStoreModule from './_store'
import SwitchGroupsStoreModule from '../switchGroups/_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/NetworkDevicesTabs')
const TheCsvImport = () => import(/* webpackChunkName: "Import" */ './_components/TheCsvImport')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'switches' }),
    goToItem: params => $router
      .push({ name: 'switch', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneSwitch', params }),
    goToNew: params => $router.push({ name: 'newSwitch', params })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_roles)
    store.registerModule('$_roles', RolesStoreModule)
  if (!store.state.$_switches)
    store.registerModule('$_switches', SwitchesStoreModule)
  if (!store.state.$_switch_groups)
    store.registerModule('$_switch_groups', SwitchGroupsStoreModule)
  next()
}

export default [
  {
    path: 'switches',
    name: 'switches',
    component: TheTabs,
    props: () => ({ tab: 'switches' }),
    beforeEnter
  },
  {
    path: 'switches/import',
    name: 'importSwitch',
    component: TheCsvImport,
    beforeEnter
  },
  {
    path: 'switches/new/:switchGroup',
    name: 'newSwitch',
    component: TheView,
    props: (route) => ({ isNew: true, switchGroup: route.params.switchGroup }),
    beforeEnter
  },
  {
    path: 'switch/:id',
    name: 'switch',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_switches/getSwitch', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'switch/:id/clone',
    name: 'cloneSwitch',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_switches/getSwitch', to.params.id).then(() => {
        next()
      })
    }
  }
]
