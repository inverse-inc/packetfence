const TheView = () => import(/* webpackChunkName: "Status" */ './_components/TheView')

export default [
  {
    path: 'dashboard_saas',
    name: 'statusDashboardSaas',
    component: TheView,
    meta: {
      can: 'read system',
      isFailRoute: true
    }
  }
]
