import store from '@/store'
import RolesStoreModule from '../roles/_store'
import SwitchesStoreModule from '../switches/_store'
import SwitchGroupsStoreModule from './_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/NetworkDevicesTabs')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

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
    path: 'switch_groups',
    name: 'switch_groups',
    component: TheTabs,
    props: (route) => ({ tab: 'switch_groups', query: route.query.query }),
    beforeEnter
  },
  {
    path: 'switch_groups/new',
    name: 'newSwitchGroup',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'switch_group/:id',
    name: 'switch_group',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_switch_groups/getSwitchGroup', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'switch_group/:id/clone',
    name: 'cloneSwitchGroup',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_switch_groups/getSwitchGroup', to.params.id).then(() => {
        next()
      })
    }
  },
]
