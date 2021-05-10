import { toRefs } from '@vue/composition-api'
import store from '@/store'
import { TheTabs } from '../_components/'
const TheView = () => import(/* webpackChunkName: "Fingerbank" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'fingerbankUserAgents' }),
    goToItem: (params, props) => {
      const { scope } = toRefs(props)
      $router
        .push({ name: 'fingerbankUserAgent', params: { ...params, scope: scope.value } })
        .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
    },
    goToClone: params => $router.push({ name: 'cloneFingerbankUserAgent', params: { ...params, scope: 'local' } })
  }
}

export default [
  {
    path: 'fingerbank/user_agents',
    name: 'fingerbankUserAgents',
    component: TheTabs,
    props: (route) => ({ tab: 'user_agents', query: route.query.query })
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
