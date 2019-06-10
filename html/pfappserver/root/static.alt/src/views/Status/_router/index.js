import store from '@/store'
import StatusView from '../'
import StatusStore from '../_store'
import Dashboard from '../_components/Dashboard'
import Services from '../_components/Services'
import Queue from '../_components/Queue'
import ClusterServices from '../_components/ClusterServices'

const route = {
  path: '/status',
  name: 'status',
  redirect: '/status/dashboard',
  component: StatusView,
  beforeEnter: (to, from, next) => {
    if (!store.state.$_status) {
      // Register store module only once
      store.registerModule('$_status', StatusStore)
    }
    store.dispatch('$_status/getCluster').then(() => next())
  },
  children: [
    {
      path: 'dashboard',
      component: Dashboard,
      props: { storeName: '$_status' },
      beforeEnter: (to, from, next) => {
        Promise.all([
          store.dispatch('config/getSources'),
          store.dispatch('$_status/allCharts')
        ]).finally(() => {
          next()
        })
      },
      meta: {
        can: 'read reports',
        fail: { path: '/auditing', replace: true }
      }
    },
    {
      path: 'services',
      component: Services,
      props: { storeName: '$_status' },
      meta: {
        can: 'read services',
        fail: { path: '/status/dashboard', replace: true }
      }
    },
    {
      path: 'queue',
      component: Queue,
      props: { storeName: 'pfqueue' },
      meta: {
        can: 'read services',
        fail: { path: '/status/dashboard', replace: true }
      }
    },
    {
      path: 'cluster/services',
      component: ClusterServices,
      props: { storeName: '$_status' },
      meta: {
        can: 'read services',
        fail: { path: '/status/dashboard', replace: true }
      }
    }
  ]
}

export default route
