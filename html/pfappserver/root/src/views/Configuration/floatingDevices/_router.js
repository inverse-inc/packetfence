import store from '@/store'
import StoreModule from './_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ '../_components/FloatingDevicesList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'floating_devices' }),
    goToItem: params => $router
      .push({ name: 'floating_device', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneFloatingDevice', params }),
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_floatingdevices)
    store.registerModule('$_floatingdevices', StoreModule)
  next()
}

export default [
  {
    path: 'floating_devices',
    name: 'floating_devices',
    component: TheList,
    props: (route) => ({ query: route.query.query }),
    beforeEnter
  },
  {
    path: 'floating_devices/new',
    name: 'newFloatingDevice',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'floating_device/:id',
    name: 'floating_device',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_floatingdevices/getFloatingDevice', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'floating_device/:id/clone',
    name: 'cloneFloatingDevice',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_floatingdevices/getFloatingDevice', to.params.id).then(() => {
        next()
      })
    }
  }
]
