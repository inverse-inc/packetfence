import store from '@/store'
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'interfaces' }),
    goToItem: params => $router
      .push({ name: 'layer2_network', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
  }
}

const can = () => !store.getters['system/isSaas']

export default [
  {
    path: 'interfaces/layer2_network/:id',
    name: 'layer2_network',
    component: TheView,
    meta: {
      can
    },
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_layer2_networks/getLayer2Network', to.params.id).then(() => {
        next()
      })
    }
  }
]
