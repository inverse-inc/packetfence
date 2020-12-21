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
        return i18n.t('TLS Profile: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone TLS Profile: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New TLS Profile')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'radiusTlss' }),
    goToItem: () => $router.push({ name: 'radiusTls', params: { id: form.value.id || id.value } }),
    goToClone: () => $router.push({ name: 'cloneRadiusTls', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_radius_tls/isLoading']),
    getOptions: () => $store.dispatch('$_radius_tls/options'),
    createItem: () => $store.dispatch('$_radius_tls/createRadiusTls', form.value),
    deleteItem: () => $store.dispatch('$_radius_tls/deleteRadiusTls', id.value),
    getItem: () => $store.dispatch('$_radius_tls/getRadiusTls', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_radius_tls/updateRadiusTls', form.value),
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
