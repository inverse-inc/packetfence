import { computed, ref, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import { useCollectionApi } from '../_api'
import { useRouter as _useRouter } from '../_router'
import { getCollection, getPlugin, usePlugins } from '../_store'

export const useItemProps = {
  plugin: {
    type: String
  },
  collection: {
    type: String
  }
}

export const useManifest = props => {
  const {
    plugin,
    collection
  } = toRefs(props)
  return computed(() => getCollection(plugin.value, collection.value) || {})
}

const itemTitle = (manifest) => manifest.item_title || manifest.title || i18n.t('Item')

// collection for useViewCollectionItem, resolved from the props on each call
// since the same view is reused between plugins
export const useCollection = props => {
  const isLoading = ref(false)
  const withLoading = promise => {
    isLoading.value = true
    return promise.finally(() => {
      isLoading.value = false
    })
  }
  const api = () => useCollectionApi(props.plugin, getCollection(props.plugin, props.collection) || {})

  return {
    useItemTitle: props => {
      const manifest = useManifest(props)
      const {
        id,
        isClone,
        isNew
      } = toRefs(props)
      return computed(() => {
        const title = itemTitle(manifest.value)
        switch (true) {
          case !isNew.value && !isClone.value:
            return i18n.t('{title} <code>{id}</code>', { title, id: id.value })
          case isClone.value:
            return i18n.t('Clone {title} <code>{id}</code>', { title, id: id.value })
          default:
            return i18n.t('New {title}', { title })
        }
      })
    },
    useItemTitleBadge: props => computed(() => {
      const plugin = getPlugin(props.plugin)
      return plugin && plugin.description
    }),
    useRouter: $router => _useRouter($router, props.plugin, props.collection),
    useStore: () => ({
      isLoading,
      getListOptions: () => withLoading(api().listOptions()),
      createItem: params => withLoading(api().create(params)),
      getItem: params => withLoading(api().item(params.id)).then(item => {
        return (params.isClone)
          ? { ...item, id: `${item.id}-${i18n.t('copy')}`, not_deletable: false }
          : item
      }),
      getItemOptions: params => withLoading(api().itemOptions(params.id)),
      updateItem: params => withLoading(api().update(params)),
      deleteItem: params => withLoading(api().delete(params.id))
    })
  }
}

const searches = {}

// one search store per plugin collection
export const useSearch = (plugin, collection) => {
  const key = `plugin_${plugin}_${collection}_${usePlugins().generation}`
  if (!(key in searches)) {
    const manifest = getCollection(plugin, collection) || {}
    const { columns = [] } = manifest
    searches[key] = makeSearch(key, {
      api: useCollectionApi(plugin, manifest),
      columns: [
        {
          key: 'selected',
          thStyle: 'width: 40px;', tdClass: 'text-center',
          locked: true
        },
        ...columns.map(column => ({
          required: column.key === 'id',
          visible: column.visible !== false,
          ...column,
          label: column.label || column.key
        })),
        {
          key: 'buttons',
          class: 'text-right p-0',
          locked: true
        },
        {
          key: 'not_deletable',
          required: true,
          visible: false
        }
      ],
      fields: columns
        .filter(column => column.searchable)
        .map(column => ({
          value: column.key,
          text: column.label || column.key,
          types: [conditionType.SUBSTRING]
        })),
      sortBy: (columns.find(column => column.sortable) || {}).key
    })
  }
  return searches[key]
}
