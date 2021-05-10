import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  collection: {
    type: String
  },
  id: {
    type: String
  },
}

export const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Filter <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Filter <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Filter')
    }
  })
}

export const useItemTitleBadge = (props, context) => {
  const {
    collection
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return computed(() => $store.getters['$_filter_engines/collectionToName'](collection.value))
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    collection,
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_filter_engines/isLoading']),
    getOptions: () => $store.dispatch('$_filter_engines/options', { collection: collection.value, id: id.value }),
    createItem: () => $store.dispatch('$_filter_engines/createFilterEngine', { collection: collection.value, data: form.value }),
    deleteItem: () => $store.dispatch('$_filter_engines/deleteFilterEngine', { collection: collection.value, id: id.value }),
    getItem: () => $store.dispatch('$_filter_engines/getFilterEngine', { collection: collection.value, id: id.value }).then(item => {
      item = JSON.parse(JSON.stringify(item)) // dereference
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_filter_engines/updateFilterEngine', { collection: collection.value, id: id.value, data: form.value }),
  }
}
