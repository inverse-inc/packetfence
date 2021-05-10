import { toRefs } from '@vue/composition-api'
import store from '@/store'

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'fingerbankDevices' }),
    goToItem: (params, props) => {
      const { scope } = toRefs(props)
      $router
        .push({ name: 'fingerbankDevice', params: { ...params, scope: scope.value } })
        .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
    },
    goToClone: params => $router.push({ name: 'cloneFingerbankDevice', params: { ...params, scope: 'local' } })
  }
}

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
