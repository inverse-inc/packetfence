/**
* Host API of the admin UI for the plugins that ship their own UI bundle
*
* The manifest of such a plugin names its bundle: { "module": "admin-ui/plugin.js", ... }.
* The bundle is fetched through the plugin API (/api/v1/plugins/<id>/<module>) and run once
* the modules it may import are loaded. It imports the modules of the admin UI from
* window.pfAdmin.modules (webpack externals, see the module names below) and describes
* itself with window.pfAdmin.define({ routes, menu }):
*
*   routes: children of the /configuration route (vue-router route configs)
*   menu:   [ { section: 'network_configuration', name, path, saveSearchNamespace, can } ]
*
* The API version is bumped when a module is removed or changes incompatibly.
*/
import apiCall from '@/utils/api'

export const API_VERSION = 1

// modules a plugin bundle can import, loaded on demand (some are heavy, ex: plotly)
const loaders = {
  'vue': () => import('vue'),
  '@vue/composition-api': () => import('@vue/composition-api'),
  'vue-awesome/components/Icon': () => import('vue-awesome/components/Icon'),
  '@/components/new': () => import('@/components/new'),
  '@/composables/useBootstrap': () => import('@/composables/useBootstrap'),
  '@/composables/useCsv': () => import('@/composables/useCsv'),
  '@/composables/useDebounce': () => import('@/composables/useDebounce'),
  '@/composables/useDom': () => import('@/composables/useDom'),
  '@/composables/useDownload': () => import('@/composables/useDownload'),
  '@/composables/useInputValue': () => import('@/composables/useInputValue'),
  '@/composables/useLogSearch': () => import('@/composables/useLogSearch'),
  '@/composables/useMeta': () => import('@/composables/useMeta'),
  '@/composables/usePreference': () => import('@/composables/usePreference'),
  '@/globals/pfSearch': () => import('@/globals/pfSearch'),
  '@/store': () => import('@/store'),
  '@/store/factory/search': () => import('@/store/factory/search'),
  '@/utils/acl': () => import('@/utils/acl'),
  '@/utils/api': () => import('@/utils/api'),
  '@/utils/bytes': () => import('@/utils/bytes'),
  '@/utils/locale': () => import('@/utils/locale'),
  '@/utils/network': () => import('@/utils/network'),
  '@/utils/plotly': () => import('@/utils/plotly'),
  '@/utils/yup': () => import('@/utils/yup'),
  '@/views/Configuration/_components/new': () => import('@/views/Configuration/_components/new'),
  '@/views/Configuration/_composables/useViewCollectionItem': () => import('@/views/Configuration/_composables/useViewCollectionItem'),
  '@/views/Configuration/fingerbank/_store': () => import('@/views/Configuration/fingerbank/_store'),
}

const host = {
  version: API_VERSION,
  modules: {},
  define: undefined
}

let modulesLoaded

const loadModules = () => {
  if (!modulesLoaded) {
    modulesLoaded = Promise.all(Object.keys(loaders).map(name => loaders[name]().then(module => {
      host.modules[name] = module
    })))
  }
  return modulesLoaded
}

// bundles are run one at a time, define() belongs to the one being run
let queue = Promise.resolve()

const run = (pluginId, code) => new Promise((resolve, reject) => {
  const url = URL.createObjectURL(new Blob([code], { type: 'text/javascript' }))
  const script = document.createElement('script')
  let definition
  host.define = def => {
    definition = def
  }
  const done = () => {
    host.define = undefined
    URL.revokeObjectURL(url)
    script.remove()
  }
  script.onload = () => {
    done()
    if (definition)
      resolve(definition)
    else
      reject(new Error(`The UI bundle of the plugin ${pluginId} did not call pfAdmin.define()`))
  }
  script.onerror = () => {
    done()
    reject(new Error(`The UI bundle of the plugin ${pluginId} could not be run`))
  }
  script.src = url
  document.head.appendChild(script)
})

// fetch and run the UI bundle of a plugin, resolves with its definition
export const loadBundle = (pluginId, module) => {
  window.pfAdmin = host
  const path = ['plugins', pluginId, ...`${module}`.split('/').filter(segment => segment)]
  const fetchCode = apiCall.get(path, { responseType: 'text', transformResponse: [data => data] })
    .then(response => {
      if (typeof response.data !== 'string')
        throw new Error(`The UI bundle of the plugin ${pluginId} is not JavaScript`)
      return response.data
    })
  const job = queue.then(() => Promise.all([fetchCode, loadModules()]))
    .then(([code]) => run(pluginId, code))
  queue = job.catch(() => {})
  return job
}

export default host
