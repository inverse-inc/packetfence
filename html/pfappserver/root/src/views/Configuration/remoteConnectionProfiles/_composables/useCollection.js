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
        return i18n.t('Remote Connection Profile <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Remote Connection Profile <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Remote Connection Profile')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'remote_connection_profiles' }),
    goToItem: () => $router.push({ name: 'remote_connection_profile', params: { id: form.value.id || id.value } }),
    goToClone: () => $router.push({ name: 'cloneRemoteConnectionProfile', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_remote_connection_profiles/isLoading']),
    getOptions: () => $store.dispatch('$_remote_connection_profiles/options'),
    createItem: () => $store.dispatch('$_remote_connection_profiles/createRemoteConnectionProfile', form.value),
    deleteItem: () => $store.dispatch('$_remote_connection_profiles/deleteRemoteConnectionProfile', id.value),
    getItem: () => $store.dispatch('$_remote_connection_profiles/getRemoteConnectionProfile', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_remote_connection_profiles/updateRemoteConnectionProfile', form.value),
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
