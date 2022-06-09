const TheView = () => import(/* webpackChunkName: "Status" */ './_components/TheView')

export default [
  {
    path: 'network_threats',
    name: 'statusNetworkThreats',
    component: TheView,
    meta: {
      can: 'read nodes'
    }
  }
]