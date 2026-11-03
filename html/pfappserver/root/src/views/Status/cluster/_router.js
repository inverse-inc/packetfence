import store from '@/store'
import acl from '@/utils/acl'

const TheView = () => import(/* webpackChunkName: "Status" */ './_components/TheView')

export default [
  {
    path: 'cluster',
    name: 'statusCluster',
    component: TheView,
    meta: {
      // not on cluster/isCluster: it is loaded asynchronously, so a reload of
      // this page would redirect away. On a standalone server the lists are empty.
      can: () => acl.$can('read', 'system') && !store.getters['system/isSaas'],
      isFailRoute: true
    }
  }
]
