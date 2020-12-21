import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta as useItemDefaults
} from '../../../_config/'

const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('SSL Certificate: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone SSL Certificate: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New SSL Certificate')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'radiusSsls' }),
    goToItem: () => $router.push({ name: 'radiusSsl', params: { id: form.value.id || id.value } }),
    goToClone: () => $router.push({ name: 'cloneRadiusSsl', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_radius_ssl/isLoading']),
    getOptions: () => $store.dispatch('$_radius_ssl/options'),
    createItem: () => $store.dispatch('$_radius_ssl/createRadiusSsl', form.value),
    deleteItem: () => $store.dispatch('$_radius_ssl/deleteRadiusSsl', id.value),
    getItem: () => $store.dispatch('$_radius_ssl/getRadiusSsl', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_radius_ssl/updateRadiusSsl', form.value),
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
