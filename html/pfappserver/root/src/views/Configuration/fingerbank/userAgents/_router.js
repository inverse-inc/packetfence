import store from '@/store'

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'fingerbankUserAgents' }),
    goToItem: params => $router
      .push({ name: 'fingerbankUserAgent', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneFingerbankUserAgent', params }),
    goToNew: params => $router.push({ name: 'newFingerbankUserAgent', params })
  }
}

import { TheTabs } from '../_components/'
const TheView = () => import(/* webpackChunkName: "Fingerbank" */ './_components/TheView')

export default [
  {
    path: 'fingerbank/user_agents',
    name: 'fingerbankUserAgents',
    component: TheTabs,
    props: () => ({ tab: 'fingerbankUserAgents', scope: 'all' })
  },
  {
    path: 'fingerbank/:scope/user_agents',
    name: 'fingerbankUserAgentsByScope',
    component: TheTabs,
    props: (route) => ({ tab: 'fingerbankUserAgents', scope: route.params.scope })
  },
  {
    path: 'fingerbank/local/user_agents/new',
    name: 'newFingerbankUserAgent',
    component: TheView,
    props: () => ({ isNew: true })
  },
  {
    path: 'fingerbank/local/user_agent/:id',
    name: 'fingerbankUserAgent',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_fingerbank/getUserAgent', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'fingerbank/local/user_agent/:id/clone',
    name: 'cloneFingerbankUserAgent',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_fingerbank/getUserAgent', to.params.id).then(() => {
        next()
      })
    }
  }
]
