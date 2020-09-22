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
    can: () => acl.can('master tenant') || acl.$some('read', ['system', 'services']), // has ACL for 1+ children
    transitionDelay: 300 * 2 // See _transitions.scss => $slide-bottom-duration
  },
  beforeEnter: (to, from, next) => {
    if (!store.state.$_status) {
      // Register store module only once
      store.registerModule('$_status', StatusStore)
    }
    if (acl.$can('read', 'system'))
      store.dispatch('$_status/getCluster').finally(() => next())
    else
      next()
  },
  children: [
    {
      path: 'dashboard',
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
        else
          next()
      },
      meta: {
        can: 'master tenant',
        isFailRoute: true
      }
    },
    {
      path: 'network',
      name: 'statusNetwork',
      component: Network,
      props: (route) => ({ query: route.query.query }),
      meta: {
        can: 'read nodes',
        isFailRoute: true
      }
    },
    {
      path: 'services',
      component: Services,
      props: { storeName: '$_status' },
      meta: {
        can: 'read services',
        isFailRoute: true
      }
    },
    {
      path: 'queue',
      component: Queue,
      props: { storeName: 'pfqueue' },
      meta: {
        can: 'master tenant',
        isFailRoute: true
      }
    },
    {
      path: 'cluster/services',
      component: ClusterServices,
      props: { storeName: '$_status' },
      meta: {
        can: 'read services'
      }
    }
  ]
}

export default route
