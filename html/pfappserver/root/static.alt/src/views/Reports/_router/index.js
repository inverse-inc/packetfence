import ReportsView from '../'
const ReportTable = () => import(/* webpackChunkName: "Reports" */ '../_components/ReportTable')
// const ReportChart = () => import(/* webpackChunkName: "Reports" */ '../_components/ReportChart')

const route = {
  path: '/reports',
  name: 'reports',
  redirect: '/reports/table/os',
  component: ReportsView,
  meta: { transitionDelay: 300 * 2 }, // See _transitions.scss => $slide-bottom-duration
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
      props: true
    }
  ]
}

export default route
