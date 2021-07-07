import acl from '@/utils/acl'
import store from '@/store'
import ReportsIndex from '../'
import ReportsStore from '../_store'

const StandardReportChart = () => import(/* webpackChunkName: "Reports" */ '../_components/StandardReportChart')
const DynamicReportChart = () => import(/* webpackChunkName: "Reports" */ '../_components/DynamicReportChart')

const route = {
  path: '/reports',
  name: 'reports',
  redirect: '/reports/standard/chart/os',
  component: ReportsIndex,
  meta: {
    can: () => acl.$some('read', ['reports']), // has ACL for 1+ children
    isFailRoute: true,
    transitionDelay: 300 * 2 // See _transitions.scss => $slide-bottom-duration
  },
  beforeEnter: (to, from, next) => {
    if (!store.state.$_reports) {
      // Register store module only once
      store.registerModule('$_reports', ReportsStore)
    }
    next()
  },
  children: [
    {
      path: 'standard/chart/:path([a-zA-Z0-9-_/]+)/',
      name: 'standardReportChart',
      component: StandardReportChart,
      props: (route) => ({ path: route.params.path }),
      meta: {
        can: 'read reports'
      }
    },
    {
      path: 'dynamic/chart/:id([a-zA-Z0-9-_ ]+)',
      name: 'dynamicReportChart',
      component: DynamicReportChart,
      props: (route) => ({ storeName: '$_reports', id: route.params.id, query: route.query.query }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_reports/getReport', to.params.id).then(() => {
          next()
        })
      },
      meta: {
        can: 'read reports'
      }
    }
  ]
}

export default route
