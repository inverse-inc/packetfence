import store from '@/store'
import StoreModule from './_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ '../_components/SwitchTemplatesList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'switchTemplates' }),
    goToItem: params => $router
      .push({ name: 'switchTemplate', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneSwitchTemplate', params }),
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_switch_templates)
    store.registerModule('$_switch_templates', StoreModule)
  next()
}

export default [
  {
    path: 'switch_templates',
    name: 'switchTemplates',
    component: TheList,
    props: (route) => ({ query: route.query.query }),
    beforeEnter
  },
  {
    path: 'switch_template/new',
    name: 'newSwitchTemplate',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'switch_template/:id',
    name: 'switchTemplate',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_switch_templates/getSwitchTemplate', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'switch_template/:id/clone',
    name: 'cloneSwitchTemplate',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_switch_templates/getSwitchTemplate', to.params.id).then(() => {
        next()
      })
    }
  }
]
