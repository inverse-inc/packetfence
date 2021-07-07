//const TheView = () => import(/* webpackChunkName: "Status" */ './_components/TheView')
const TheSearch = () => import(/* webpackChunkName: "Status" */ './_components/TheSearch')

export default [
  {
    path: 'network',
    name: 'statusNetwork',
    component: TheSearch,
    meta: {
      can: 'read nodes',
      isFailRoute: true
    }
  }
]
