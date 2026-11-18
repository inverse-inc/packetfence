/**
 * The composables of a plugin page, built from its manifest: what the
 * _composables/useCollection.js or useResource.js of a core view provide to
 * useViewCollectionItem / useViewResource and to the search.
 */
import { computed, toRefs } from '@vue/composition-api'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import i18n from '@/utils/locale'
import { allowedApi, escapeHtml as escape, manifestGeneration, pluginRouteNames, translate, usePlugin } from './'
import { pluginApi, useStore } from './store'

export const useRouter = plugin => {
  const names = pluginRouteNames(plugin)
  return $router => ({
    goToCollection: () => $router.push({ name: names.collection }),
    goToItem: params => $router
      .push({ name: names.item, params: { id: params.id } })
      .catch(e => { if (e.name !== 'NavigationDuplicated') throw e }),
    ...((allowedApi(plugin.manifest).create)
      ? {
        goToClone: params => $router.push({ name: names.clone, params: { id: params.id } }),
        goToNew: () => $router.push({ name: names.new })
      }
      : {}
    )
  })
}

/**
 * useViewCollectionItem(collection, ...)
 */
export const useCollection = plugin => {
  const { manifest } = plugin
  const title = () => escape(translate(manifest.title))
  return {
    useItemTitle: props => {
      const { id, isClone, isNew } = toRefs(props)
      return computed(() => {
        switch (true) {
          case !isNew.value && !isClone.value:
            return `${title()} <code>${escape(id.value)}</code>`
          case isClone.value:
            return i18n.t('Clone {title} <code>{id}</code>', { title: title(), id: escape(id.value) })
          default:
            return i18n.t('New {title}', { title: title() })
        }
      })
    },
    useRouter: useRouter(plugin),
    useStore: useStore(plugin)
  }
}

/**
 * useViewResource(resource, ...)
 */
export const useResource = plugin => {
  const { manifest } = plugin
  return {
    useTitle: () => computed(() => escape(translate(manifest.title))),
    useStore: useStore(plugin)
  }
}

// The uuid of a search store. makeSearch makes the pinia store id with
// toKebabCase, which drops "-" and "_" (acme-x and acme_x would share a store)
// and splits on digits: only lowercase letters go through unchanged, so the
// uuid is spelled with them ("z" escapes the other characters). Each manifest
// gets its own store: pinia keeps a store by id, a manifest reloaded with
// other columns or api must not get the store of the old one.
const escapes = '0123456789_-z'
const spell = s => [...s].map(c => ((c >= 'a' && c < 'z') ? c : `z${'abcdefghijklm'[escapes.indexOf(c)]}`)).join('')
let searchStores = 0
export const searchUuid = (id, generation) => `plugin${spell(`${id}-${generation}`)}`

// the search store of the newest manifest of each plugin: the one of an older
// manifest is disposed when a newer one gets its own (pinia keeps a store
// until it is disposed); never the other way around (a page of an earlier
// load still mounted after a new login)
const latestSearches = new Map()

/**
 * The search of a collection, as the makeSearch of a core view
 */
const searches = new WeakMap()
export const useSearch = plugin => {
  const { id, manifest } = plugin
  if (!searches.has(manifest)) {
    const previous = latestSearches.get(id)
    const newest = !previous || manifestGeneration(manifest) >= manifestGeneration(previous.manifest)
    if (previous && newest)
      previous.useSearchStore().$dispose()
    const { list, search } = pluginApi(manifest)
    const { collection: { columns = [], searchFields = [] } } = manifest
    const keys = columns.map(({ key }) => key)
    searches.set(manifest, makeSearch(searchUuid(id, ++searchStores), {
      api: { ...((list) ? { list } : {}), ...((search) ? { search } : {}) },
      columns: [
        { key: 'selected', thStyle: 'width: 40px;', tdClass: 'text-center', locked: true },
        ...columns.map(({ key, label, sortable }, index) => ({
          key,
          label: translate(label),
          required: index === 0,
          searchable: searchFields.includes(key),
          sortable: !!sortable,
          visible: true
        })),
        { key: 'buttons', class: 'text-right p-0', locked: true },
        ...((keys.includes('not_deletable')) ? [] : [{ key: 'not_deletable', required: true, visible: false }])
      ],
      fields: searchFields.map(key => {
        const column = columns.find(column => column.key === key)
        return { value: key, text: translate((column && column.label) || { en: key }), types: [conditionType.SUBSTRING] }
      }),
      sortBy: keys[0]
    }))
    if (newest)
      latestSearches.set(id, { manifest, useSearchStore: searches.get(manifest) })
  }
  return searches.get(manifest)
}

export { usePlugin }
