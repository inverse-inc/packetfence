const TheView = () => import(/* webpackChunkName: "Status" */ './_components/TheView')

export default [
  {
    path: 'network_communication',
    name: 'statusNetworkCommunication',
    component: TheView,
    meta: {
      can: 'read nodes'
    }
  }
]
