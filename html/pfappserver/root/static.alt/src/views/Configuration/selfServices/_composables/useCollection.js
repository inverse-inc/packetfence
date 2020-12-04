import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta as useItemDefaults
} from '../../_config/'

const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Self Service: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Self Service: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Self Service')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'self_services' }),
    goToItem: () => $router.push({ name: 'self_service', params: { id: form.value.id || id.value } }),
    goToClone: () => $router.push({ name: 'cloneSelfService', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_self_services/isLoading']),
    getOptions: () => $store.dispatch('$_self_services/options'),
    createItem: () => $store.dispatch('$_self_services/createSelfService', form.value),
    deleteItem: () => $store.dispatch('$_self_services/deleteSelfService', id.value),
    getItem: () => $store.dispatch('$_self_services/getSelfService', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_self_services/updateSelfService', form.value),
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
