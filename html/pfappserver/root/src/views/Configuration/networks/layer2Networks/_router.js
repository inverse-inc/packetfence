import store from '@/store'
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export default [
  {
    path: 'interfaces/layer2_network/:id',
    name: 'layer2_network',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_layer2_networks/getLayer2Network', to.params.id).then(() => {
        next()
      })
    }
  }
]
