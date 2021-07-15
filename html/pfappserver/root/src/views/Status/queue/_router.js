const TheView = () => import(/* webpackChunkName: "Status" */ './_components/TheView')

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
