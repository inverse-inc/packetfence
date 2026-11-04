import store from '@/store'
import StoreModule from './_store'

const TheSearch = () => import(/* webpackChunkName: "ConfigurationPlugins" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "ConfigurationPlugins" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'adminUiPlugins' }),
    goToItem: params => $router
      .push({ name: 'adminUiPlugin', params })
      .catch(e => { if (e.name !== 'NavigationDuplicated') throw e }),
    goToClone: params => $router.push({ name: 'cloneAdminUiPlugin', params }),
    goToNew: params => $router.push({ name: 'newAdminUiPlugin', params })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_admin_ui_plugins)
    store.registerModule('$_admin_ui_plugins', StoreModule)
  next()
}

export default [
  {
    path: 'admin_ui_plugins',
    name: 'adminUiPlugins',
    component: TheSearch,
    beforeEnter
  },
  {
    path: 'admin_ui_plugins/new',
    name: 'newAdminUiPlugin',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'admin_ui_plugins/:id',
    name: 'adminUiPlugin',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_admin_ui_plugins/getAdminUiPlugin', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'admin_ui_plugins/:id/clone',
    name: 'cloneAdminUiPlugin',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_admin_ui_plugins/getAdminUiPlugin', to.params.id).then(() => {
        next()
      })
    }
  }
]
