import store from '@/store'
import StoreModule from './_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../../_components/RadiusTabs')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_radius_fast) {
    store.registerModule('$_radius_fast', StoreModule)
  }
  next()
}

export default [
  {
    path: 'radius/fast',
    name: 'radiusFasts',
    component: TheTabs,
    props: (route) => ({ tab: 'radiusFasts', query: route.query.query }),
    beforeEnter
  },
  {
    path: 'radius/fast_new',
    name: 'newRadiusFast',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'radius/fast/:id',
    name: 'radiusFast',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_radius_fast/getRadiusFast', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'radius/fast/:id/clone',
    name: 'cloneRadiusFast',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_radius_fast/getRadiusFast', to.params.id).then(() => {
        next()
      })
    }
  }
]
