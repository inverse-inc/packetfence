import store from '@/store'
import StoreModule from './_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/TheTabsMain')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'maintenance_tasks' }),
    goToItem: params => $router
      .push({ name: 'maintenance_task', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_maintenance_tasks)
    store.registerModule('$_maintenance_tasks', StoreModule)
  next()
}

export default [
  {
    path: 'maintenance_tasks',
    name: 'maintenance_tasks',
    component: TheTabs,
    props: () => ({ tab: 'maintenance_tasks' }),
    beforeEnter
  },
  {
    path: 'maintenance_task/:id',
    name: 'maintenance_task',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_maintenance_tasks/getMaintenanceTask', to.params.id).then(() => {
        next()
      })
    }
  }
]
