import store from '@/store'

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'fingerbankDevices' }),
    goToItem: params => $router
      .push({ name: 'fingerbankDevice', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneFingerbankDevice', params }),
    goToNew: params => $router.push({ name: 'newFingerbankDevice', params })
  }
}

import { TheTabs } from '../_components/'
const TheView = () => import(/* webpackChunkName: "Fingerbank" */ './_components/TheView')

export default [
  {
    path: 'fingerbank/devices',
    name: 'fingerbankDevices',
    component: TheTabs,
    props: () => ({ tab: 'devices', scope: 'all', parentId: undefined })
  },
  {
    path: 'fingerbank/:scope/devices',
    name: 'fingerbankDevicesByScope',
    component: TheTabs,
    props: (route) => ({ tab: 'devices', scope: route.params.scope, parentId: undefined })
  },
  {
    path: 'fingerbank/devices/:parentId',
    name: 'fingerbankDevicesByParentId',
    component: TheTabs,
    props: (route) => ({ tab: 'devices', scope: 'all', parentId: route.params.parentId })
  },
  {
    path: 'fingerbank/:scope/devices/new',
    name: 'newFingerbankDevice',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, isNew: true })
  },
  {
    path: 'fingerbank/:scope/device/:id',
    name: 'fingerbankDevice',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, id: route.params.id }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_fingerbank/getDevice', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'fingerbank/:scope/device/:id/clone',
    name: 'cloneFingerbankDevice',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_fingerbank/getDevice', to.params.id).then(() => {
        next()
      })
    }
  }
]
