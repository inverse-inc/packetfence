import store from '@/store'
import { TheTabs } from '../_components/'
const TheView = () => import(/* webpackChunkName: "Fingerbank" */ './_components/TheView')

export default [
  {
    path: 'fingerbank/devices',
    name: 'fingerbankDevices',
    component: TheTabs,
    props: (route) => ({ tab: 'devices', query: route.query.query })
  },
  {
    path: 'fingerbank/devices/:parentId',
    name: 'fingerbankDevicesByParentId',
    component: TheTabs,
    props: (route) => ({ parentId: route.params.parentId, tab: 'devices', query: route.query.query })
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
