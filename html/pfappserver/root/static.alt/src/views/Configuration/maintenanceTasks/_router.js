import store from '@/store'
import StoreModule from './_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/MainTabs')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export default [
  {
    path: 'maintenance_tasks',
    name: 'maintenance_tasks',
    component: TheTabs,
    props: (route) => ({ tab: 'maintenance_tasks', query: route.query.query }),
    beforeEnter: (to, from, next) => {
      if (!store.state.$_maintenance_tasks) {
        store.registerModule('$_maintenance_tasks', StoreModule)
      }
      next()
    }
  },
  {
    path: 'maintenance_task/:id',
    name: 'maintenance_task',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      if (!store.state.$_maintenance_tasks) {
        store.registerModule('$_maintenance_tasks', StoreModule)
      }
      store.dispatch('$_maintenance_tasks/getMaintenanceTask', to.params.id).then(() => {
        next()
      })
    }
  }
]
