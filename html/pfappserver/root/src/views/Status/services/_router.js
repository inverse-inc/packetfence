const TheView = () => import(/* webpackChunkName: "Status" */ './_components/TheView')

export default [
  {
    path: 'services',
    name: 'statusServices',
    component: TheView,
    meta: {
      can: 'read services',
      isFailRoute: true
    }
  }
]
