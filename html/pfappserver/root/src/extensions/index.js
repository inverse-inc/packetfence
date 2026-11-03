/**
 * UI extensions: merge the routes, sidebar items, navbar items, store modules
 * and translations of the extensions compiled into this build (see
 * extensions/README.md) with the core ones.
 *
 * Without any extension, every function returns its input unchanged.
 *
 * Do not import '@/router' or '@/store' here: this module is evaluated while the
 * router is being built.
 */
import registry from '@/extensions/registry'

const PREFIX = '[pf-ui-extensions]'

/* eslint-disable no-console */
const logError = (...args) => console.error(PREFIX, ...args)
const logWarning = (...args) => console.warn(PREFIX, ...args)
const logInfo = (...args) => console.info(PREFIX, ...args)
/* eslint-enable no-console */

export const extensions = registry.map(({ id, definition, messages }) => ({
  ...(definition || {}),
  id,
  messages: messages || {}
}))

const asArray = value => (Array.isArray(value) ? value : ((value) ? [value] : []))
const resolve = (value, context) => ((typeof value === 'function') ? value(context) : value)

/**
 * Routes
 */

// absolute path of a route given the absolute path of its parent
const fullPath = (base, path = '') => {
  if (path.startsWith('/'))
    return path
  return `${(base || '').replace(/\/$/, '')}/${path}`
}

// find a route by name or by absolute path, at any depth
const findRoute = (routes, key, base = '') => {
  for (const route of routes) {
    const routePath = fullPath(base, route.path)
    if (route.name === key || routePath === key)
      return { route, path: routePath }
    if (Array.isArray(route.children)) {
      const found = findRoute(route.children, key, routePath)
      if (found)
        return found
    }
  }
  return undefined
}

/**
 * Add the extensions routes to the core route tree, in place, and return it.
 *
 * Each extension route is added under `parent` (a route name or an absolute
 * path, at any depth) or at the root level without a parent. A route with the
 * same name or path as an existing sibling replaces it.
 *
 * The arrays are modified in place on purpose: the areas routers that iterate
 * their own `children` (eg: the Status redirect) see the extensions routes.
 */
// all the route names, at any depth
const routeNames = (routes, names = new Set()) => {
  for (const route of routes) {
    if (route.name)
      names.add(route.name)
    if (Array.isArray(route.children))
      routeNames(route.children, names)
  }
  return names
}

export const applyRoutes = routes => {
  for (const { id, routes: extensionRoutes } of extensions) {
    for (const { parent, ...route } of asArray(extensionRoutes)) {
      if (typeof route.path !== 'string') {
        logError(`${id}: route "${route.name}" without a path ignored`)
        continue
      }
      let siblings = routes
      let base = ''
      if (parent) {
        const found = findRoute(routes, parent)
        if (!found) {
          logError(`${id}: parent route "${parent}" not found, route "${route.name || route.path}" ignored`)
          continue
        }
        if (!Array.isArray(found.route.children))
          found.route.children = []
        siblings = found.route.children
        base = found.path
      }
      else if (!route.path.startsWith('/')) {
        logError(`${id}: root route "${route.name || route.path}" must have an absolute path, ignored`)
        continue
      }
      route.meta = { ...route.meta, extension: id }
      const path = fullPath(base, route.path)
      const index = siblings.findIndex(sibling => (route.name && sibling.name === route.name) || fullPath(base, sibling.path) === path)
      if (index > -1) {
        logInfo(`${id}: route "${route.name || path}" overrides "${siblings[index].name || path}"`)
        siblings.splice(index, 1, route)
      }
      else {
        // vue-router keeps the first route of a name, the extension route would not be reachable by name
        if (route.name && routeNames(routes).has(route.name))
          logError(`${id}: route name "${route.name}" is already used elsewhere, use a unique name or the same parent to override it`)
        siblings.push(route)
      }
    }
  }
  return routes
}

/**
 * Sidebars
 */

const samePath = (a, b) => (a === b || (!!a && !!b && typeof a === 'object' && typeof b === 'object' && JSON.stringify(a) === JSON.stringify(b)))

// copy the arrays of the sections tree, items can be Promises (ignored)
const copySections = list => list.map(item => ((Array.isArray(item.items)) ? { ...item, items: copySections(item.items) } : item))

// find an item by path, at any depth
const findItem = (list, path) => {
  for (let index = 0; index < list.length; index++) {
    const item = list[index]
    if (item.path && samePath(item.path, path))
      return { list, index }
    if (Array.isArray(item.items)) {
      const found = findItem(item.items, path)
      if (found)
        return found
    }
  }
  return undefined
}

const insertItem = (id, list, item, before, after) => {
  const anchor = before || after
  if (anchor) {
    const index = list.findIndex(sibling => samePath(sibling.path, anchor))
    if (index > -1) {
      list.splice((before) ? index : index + 1, 0, item)
      return
    }
    logWarning(`${id}: sidebar item "${JSON.stringify(anchor)}" not found, "${item.name}" appended`)
  }
  list.push(item)
}

/**
 * Merge the extensions sidebar contributions for an area (the route name of a
 * top-level view: 'configuration', 'status', ...) with the core sections.
 *
 * A contribution `{ parent, group, item, before, after }`:
 *  - replaces the item with the same path, anywhere in the tree
 *  - or is added to the items of `parent` (a section path, at any depth), in
 *    its group named `group` (untranslated name) if any
 *  - or is a new top-level section without `parent`
 */
export const areaSections = (area, sections, context = {}) => {
  const contributions = extensions.reduce((contributions, { id, sidebar = {} }) => {
    return [ ...contributions, ...asArray(resolve(sidebar[area], context)).map(contribution => ({ ...contribution, id })) ]
  }, [])
  if (contributions.length === 0)
    return sections
  const { i18n } = context
  const tree = copySections(sections)
  for (const { id, parent, group, item, before, after } of contributions) {
    if (!item) {
      logError(`${id}: sidebar contribution without an item ignored`)
      continue
    }
    if (item.path) {
      const found = findItem(tree, item.path)
      if (found) {
        found.list.splice(found.index, 1, item)
        continue
      }
    }
    let list = tree
    if (parent) {
      const found = findItem(tree, parent)
      if (!found || !Array.isArray(found.list[found.index].items)) {
        logError(`${id}: sidebar section "${JSON.stringify(parent)}" not found, "${item.name}" ignored`)
        continue
      }
      list = found.list[found.index].items
    }
    if (group) {
      const name = (i18n) ? i18n.t(group) : group
      const found = list.find(sibling => !sibling.path && Array.isArray(sibling.items) && [name, group].includes(sibling.name))
      if (!found) {
        logError(`${id}: sidebar group "${group}" not found, "${item.name}" ignored`)
        continue
      }
      list = found.items
    }
    insertItem(id, list, item, before, after)
  }
  return tree
}

/**
 * Navbar
 */
export const navbarItems = extensions.reduce((items, { id, navbar }) => {
  return [ ...items, ...asArray(navbar).map(item => ({ ...item, extension: id })) ]
}, [])

/**
 * Store modules and install hooks, called once before the root Vue instance is
 * created.
 */
export const installExtensions = ({ Vue, router, store, i18n, pinia }) => {
  for (const { id, storeModules, install } of extensions) {
    for (const [name, module] of Object.entries(storeModules || {})) {
      if (store.hasModule(name)) {
        logError(`${id}: store module "${name}" already exists, ignored`)
        continue
      }
      if (name.startsWith('$_')) {
        logError(`${id}: store module "${name}" is a temporary module (unregistered on logout), register it lazily in a route beforeEnter instead, ignored`)
        continue
      }
      if (!(module.mutations && module.mutations.$RESET))
        logWarning(`${id}: store module "${name}" has no $RESET mutation, logout will fail to reset it`)
      store.registerModule(name, module)
    }
    if (typeof install === 'function')
      install(Vue, { router, store, i18n, pinia })
  }
}

/**
 * Translations, from `<extension>/i18n/<lang>.po`, merged once the core lexicon
 * of a language is loaded.
 */
export const loadExtensionMessages = lang => {
  const [ base ] = `${lang}`.split(/[-_]/)
  const loaders = extensions
    .map(({ messages }) => messages[lang] || messages[base])
    .filter(loader => loader)
  // a translation that fails to load must not prevent the language change
  return Promise.all(loaders.map(loader => loader()
    .then(module => module.default || module)
    .catch(err => {
      logError(`translations "${lang}" failed to load`, err)
      return {}
    })))
    .then(all => Object.assign({}, ...all))
}
