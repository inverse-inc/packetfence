import acl from '@/utils/acl'
import store from '@/store'
import StatusView from '../'
import StatusStore from '../_store'
import Dashboard from '../_components/Dashboard'
import Network from '../_components/Network'
import Services from '../_components/Services'
import Queue from '../_components/Queue'
import ClusterServices from '../_components/ClusterServices'

const route = {
  path: '/status',
  name: 'status',
  redirect: '/status/dashboard',
  component: StatusView,
  meta: {
    can: () => {
      return acl.can('master tenant') || acl.$some('read', ['nodes', 'services']) // has ACL for 1+ children
    },
    fail: { path: '/reports', replace: true }, // no ACL in this view, redirect to next sibling
    transitionDelay: 300 * 2 // See _transitions.scss => $slide-bottom-duration
  },
  beforeEnter: (to, from, next) => {
    if (!store.state.$_status) {
      // Register store module only once
      store.registerModule('$_status', StatusStore)
    }
    if (acl.$can('read', 'system'))
      store.dispatch('$_status/getCluster').then(() => next())
    else
      next()
  },
  children: [
    {
      path: 'dashboard',
      name: 'statusDashboard',
      component: Dashboard,
      props: { storeName: '$_status' },
      beforeEnter: (to, from, next) => {
        if (acl.$can('read', 'users_sources'))
          store.dispatch('config/getSources')
        if (acl.$can('read', 'system')) {
          store.dispatch('$_status/getCluster').then(() => {
            store.dispatch('$_status/allCharts').finally(() => next())
          }).catch(() => next())
        }
      },
      meta: {
        can: 'master tenant',
        fail: { name: 'statusNetwork', replace: true } // redirect to next sibling
      }
    },
    {
      path: 'network',
      name: 'statusNetwork',
      component: Network,
      props: (route) => ({ query: route.query.query }),
      meta: {
        can: 'read nodes',
        fail: { name: 'statusServices', replace: true } // redirect to next sibling
      }
    },
    {
      path: 'services',
      name: 'statusServices',
      component: Services,
      props: { storeName: '$_status' },
      meta: {
        can: 'read services',
        fail: { name: 'statusQueue', replace: true } // redirect to next sibling
      }
    },
    {
      path: 'queue',
      name: 'statusQueue',
      component: Queue,
      props: { storeName: 'pfqueue' },
      meta: {
        can: 'master tenant',
        fail: { name: 'statusCluster', replace: true } // redirect to next sibling
      }
    },
    {
      path: 'cluster/services',
      name: 'statusCluster',
      component: ClusterServices,
      props: { storeName: '$_status' },
      meta: {
        can: 'read services',
        fail: { name: 'statusDashboard', replace: true } // redirect to first sibling
      }
    }
  ]
}

export default route
