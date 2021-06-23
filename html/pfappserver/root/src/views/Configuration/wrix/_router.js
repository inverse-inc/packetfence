import store from '@/store'
import StoreModule from './_store'

const TheSearch = () => import(/* webpackChunkName: "Configuration" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'wrixLocations' }),
    goToItem: params => $router
      .push({ name: 'wrixLocation', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneWrixLocation', params }),
    goToNew: () => $router.push({ name: 'newWrixLocation' })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_wrix_locations)
    store.registerModule('$_wrix_locations', StoreModule)
  next()
}

export default [
  {
    path: 'wrix',
    name: 'wrixLocations',
    component: TheSearch,
    beforeEnter
  },
  {
    path: 'wrix/new',
    name: 'newWrixLocation',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'wrix/:id',
    name: 'wrixLocation',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_wrix_locations/getWrixLocation', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'wrix/:id/clone',
    name: 'cloneWrixLocation',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_wrix_locations/getWrixLocation', to.params.id).then(() => {
        next()
      })
    }
  }
]
