import store from '@/store'
import StatusView from '../'
import StatusStore from '../_store'
import Dashboard from '../_components/Dashboard'
import Services from '../_components/Services'

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
    next()
  },
  children: [
    {
      path: 'dashboard',
      component: Dashboard,
      props: { storeName: '$_status' },
      beforeEnter: (to, from, next) => {
        Promise.all([
          store.dispatch('config/getSources'),
          store.dispatch('$_status/getCluster'),
          store.dispatch('$_status/allCharts')
        ]).then(() => {
          next()
        })
      }
      // TODO: meta/can
    },
    {
      path: 'services',
      component: Services,
      props: { storeName: '$_status' },
      meta: {
        can: 'access services'
      }
    }
  ]
}

export default route
