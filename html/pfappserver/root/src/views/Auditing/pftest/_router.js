import store from '@/store'
import { loadClusterConfig } from '@/utils/cluster'
import StoreModule from './_store'

const TheView = () => import(/* webpackChunkName: "Auditing" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_pftest) {
    store.registerModule('$_pftest', StoreModule)
  }
  // The peer list drives the "run on all cluster nodes" opt-in checkbox.
  loadClusterConfig().finally(() => next())
}

export default [
  {
    path: 'pftest',
    name: 'pftest',
    component: TheView,
    // 'create pftest' = PFTEST_CREATE, the role the Go api-frontend enforces
    // on POST /api/v1/pftest/* — frontend and backend stay aligned.
    meta: { can: 'create pftest' },
    beforeEnter
  }
]
