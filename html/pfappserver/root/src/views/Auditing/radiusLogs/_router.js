import store from '@/store'
import StoreModule from './_store'

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'radiuslogs' }),
    goToItem: params => $router
      .push({ name: 'radiuslog', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
  }
}

const TheSearch = () => import(/* webpackChunkName: "Auditing" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "Auditing" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_radius_logs) {
    store.registerModule('$_radius_logs', StoreModule)
  }
  next()
}

export default [
  {
    path: 'radiuslogs/search',
    name: 'radiuslogs',
    component: TheSearch,
    meta: {
      can: 'read radius_log',
      isFailRoute: true
    },
    beforeEnter
  },
  {
    path: 'radiuslog/:id',
    name: 'radiuslog',
    component: TheView,
    props: (route) => ({ storeName: '$_radius_logs', id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_radius_logs/getItem', to.params.id).finally(() => {
        next()
      })
    },
    meta: {
      can: 'read radius_log'
    }
  }
]