import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { defaultsFromMeta } from '../../_config/'

export const useItemProps = {
  id: {
    type: String
  },
  cloudType: {
    type: String
  }
}

const useItemDefaults = (meta, props) => {
  const {
    cloudType
  } = toRefs(props)
  return { ...defaultsFromMeta(meta), type: cloudType.value }
}

const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Cloud Service <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Cloud Service <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Cloud Service')
    }
  })
}

const useItemTitleBadge = (props, context, form) => {
  const {
    cloudType
  } = toRefs(props)
  return computed(() => (cloudType.value || form.value.type))
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'clouds' }),
    goToItem: (item = form.value || {}) => $router
      .push({ name: 'cloud', params: { id: item.id } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneCloud', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone,
    isNew,
    cloudType
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_clouds/isLoading']),
    getOptions: () => {
      if (isNew.value)
        return $store.dispatch('$_clouds/optionsByCloudType', cloudType.value)
      else
        return $store.dispatch('$_clouds/optionsById', id.value)
    },
    createItem: () => $store.dispatch('$_clouds/createCloud', form.value),
    deleteItem: () => $store.dispatch('$_clouds/deleteCloud', id.value),
    getItem: () => $store.dispatch('$_clouds/getCloud', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_clouds/updateCloud', form.value),
  }
}

export default {
  useItemDefaults,
  useItemProps,
  useItemTitle,
  useItemTitleBadge,
  useRouter,
  useStore,
}
