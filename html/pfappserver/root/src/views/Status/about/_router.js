const TheView = () => import(/* webpackChunkName: "Status" */ './_components/TheView')

export default [
  {
    path: 'about',
    name: 'statusAbout',
    component: TheView,
    meta: {
      can: 'read system'
    }
  }
]
