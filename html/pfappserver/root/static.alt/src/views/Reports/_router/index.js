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
  beforeEnter: (to, from, next) => {
    if (!store.state.$_reports) {
      // Register store module only once
      store.registerModule('$_reports', ReportsStore)
    }
    next()
  },
  children: [
    {
      path: 'standard/chart/:path([a-zA-Z0-9-_/]+)/:start_datetime?/:end_datetime?',
      name: 'standardReportChart',
      component: StandardReportChart,
      props: (route) => ({
        path: route.params.path,
        start_datetime: route.params.start_datetime,
        end_datetime: route.params.end_datetime
      }),
      meta: {
        can: 'read reports',
        fail: { path: '/auditing', replace: true }
      }
    },
    {
      path: 'dynamic/chart/:id([a-zA-Z0-9-_ ]+)',
      name: 'dynamicReportChart',
      component: DynamicReportChart,
      props: (route) => ({ storeName: '$_reports', id: route.params.id, query: route.query.query }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_reports/getReport', to.params.id).then(object => {
          next()
        })
      },
      meta: {
        can: 'read reports',
        fail: { path: '/auditing', replace: true }
      }
    }
  ]
}

export default route
