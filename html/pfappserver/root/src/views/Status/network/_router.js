const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export default [
  {
    path: 'network',
    name: 'statusNetwork',
    component: TheView,
    meta: {
      can: 'read nodes',
      isFailRoute: true
    }
  }
]
