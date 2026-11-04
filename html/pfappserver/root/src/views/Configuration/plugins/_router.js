import { load } from './_store'

const TheSearch = () => import(/* webpackChunkName: "ConfigurationPlugins" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "ConfigurationPlugins" */ './_components/TheView')

export const useRouter = ($router, plugin, collection) => {
  return {
    goToCollection: () => $router.push({ name: 'pluginCollection', params: { plugin, collection } }),
    goToItem: params => $router
      .push({ name: 'pluginItem', params: { plugin, collection, id: params.id } })
      .catch(e => { if (e.name !== 'NavigationDuplicated') throw e }),
    goToClone: params => $router.push({ name: 'clonePluginItem', params: { plugin, collection, id: params.id } }),
    goToNew: () => $router.push({ name: 'newPluginItem', params: { plugin, collection } })
  }
}

// the manifests must be loaded before rendering a plugin view
export const beforeEnter = (to, from, next) => {
  load().then(() => next())
}

export default [
  {
    path: 'plugins/:plugin/:collection',
    name: 'pluginCollection',
    component: TheSearch,
    props: route => ({ plugin: route.params.plugin, collection: route.params.collection }),
    beforeEnter
  },
  {
    path: 'plugins/:plugin/:collection/new',
    name: 'newPluginItem',
    component: TheView,
    props: route => ({ plugin: route.params.plugin, collection: route.params.collection, isNew: true }),
    beforeEnter
  },
  {
    path: 'plugins/:plugin/:collection/:id',
    name: 'pluginItem',
    component: TheView,
    props: route => ({ plugin: route.params.plugin, collection: route.params.collection, id: route.params.id }),
    beforeEnter
  },
  {
    path: 'plugins/:plugin/:collection/:id/clone',
    name: 'clonePluginItem',
    component: TheView,
    props: route => ({ plugin: route.params.plugin, collection: route.params.collection, id: route.params.id, isClone: true }),
    beforeEnter
  }
]
