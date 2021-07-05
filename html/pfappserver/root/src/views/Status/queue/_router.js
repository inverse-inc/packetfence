const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export default [
  {
    path: 'queue',
    name: 'statusQueue',
    component: TheView,
    meta: {
      can: 'master tenant',
      isFailRoute: true
    }
  }
]
