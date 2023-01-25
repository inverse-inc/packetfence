import store from '@/store'
const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../../_components/TheTabsNetworks')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: params => {
      const { prefixRouteName } = params
      return $router.push({ name: `${prefixRouteName}interfaces` })
    },
    goToItem: params => {
      let { prefixRouteName, id, vlan } = params
      if (id.indexOf('.') === -1 && vlan) // if `id` omits `vlan` and `vlan` is defined
        id += `.${vlan}` // append `vlan` to `id`
      return $router.push({ name: `${prefixRouteName}interface`, params: { id } })
        .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
    },
    goToClone: params => {
      const { prefixRouteName } = params
      return $router.push({ name: `${prefixRouteName}cloneInterface`, params })
    }
  }
}

const can = () => !store.getters['system/isSaas']

export default [
  {
    path: 'interfaces',
    name: 'interfaces',
    component: TheTabs,
    meta: {
      can
    },
    props: () => ({ tab: 'interfaces' })
  },
  {
    path: 'interface/:id',
    name: 'interface',
    component: TheView,
    meta: {
      can
    },
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_interfaces/getInterface', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'interface/:id/clone',
    name: 'cloneInterface',
    component: TheView,
    meta: {
      can
    },
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_interfaces/getInterface', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'interface/:id/new',
    name: 'newInterface',
    component: TheView,
    meta: {
      can
    },
    props: (route) => ({ id: route.params.id, isNew: true }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_interfaces/getInterface', to.params.id).then(() => {
        next()
      })
    }
  }
]
