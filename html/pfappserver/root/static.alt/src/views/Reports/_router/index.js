import ReportsView from '../'
const ReportTable = () => import(/* webpackChunkName: "Reports" */ '../_components/ReportTable')
// const ReportChart = () => import(/* webpackChunkName: "Reports" */ '../_components/ReportChart')

const route = {
  path: '/reports',
  name: 'reports',
  redirect: '/reports/table/os',
  component: ReportsView,
  props: { storeName: '$_reports' },
  children: [
    // {
    //   path: 'graph/:report',
    //   name: 'graph',
    //   component: ReportChart,
    //   props: true
    // },
    {
      path: 'table/:path([a-zA-Z0-9/]+)/:start_datetime?/:end_datetime?',
      name: 'table',
      component: ReportTable,
      props: (route) => ({
        storeName: '$_reports',
        path: route.params.path,
        start_datetime: route.params.start_datetime,
        end_datetime: route.params.end_datetime
      })
    }
  ]
}

export default route
