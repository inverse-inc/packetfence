import store from '@/store'
import acl from '@/utils/acl'

const TheView = () => import(/* webpackChunkName: "Status" */ './_components/TheView')

export default [
  {
    path: 'cluster',
    name: 'statusCluster',
    component: TheView,
    meta: {
      can: () => acl.$can('read', 'system') && !store.getters['system/isSaas'] && store.getters['cluster/isCluster'],
      isFailRoute: true
    }
  }
]
