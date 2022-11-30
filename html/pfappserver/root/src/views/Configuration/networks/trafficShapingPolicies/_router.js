import store from '@/store'
const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../../_components/TheTabsNetworks')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'traffic_shapings' }),
    goToItem: params => $router
      .push({ name: 'traffic_shaping', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToNew: () => $router.push({ name: 'newTrafficShaping' })
  }
}

const can = () => !store.getters['system/isSaas']

export default [
  {
    path: 'traffic_shapings',
    name: 'traffic_shapings',
    component: TheTabs,
    meta: {
      can
    },
    props: () => ({ tab: 'traffic_shapings' })
  },
  {
    path: 'traffic_shaping/new/:role',
    name: 'newTrafficShaping',
    component: TheView,
    meta: {
      can
    },
    props: (route) => ({ isNew: true, role: route.params.role })
  },
  {
    path: 'traffic_shaping/:id',
    name: 'traffic_shaping',
    component: TheView,
    meta: {
      can
    },
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_traffic_shaping_policies/getTrafficShapingPolicy', to.params.id).then(() => {
        next()
      })
    }
  }
]
