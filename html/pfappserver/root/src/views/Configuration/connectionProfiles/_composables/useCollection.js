import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta as useItemDefaults
} from '../../_config/'

export const useItemProps = {
  id: {
    type: String
  }
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
        return i18n.t('Standard Connection Profile <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Standard Connection Profile <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Standard Connection Profile')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'connection_profiles' }),
    goToItem: (item = form.value || {}) => $router
      .push({ name: 'connection_profile', params: { id: item.id } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneConnectionProfile', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_connection_profiles/isLoading']),
    getOptions: () => $store.dispatch('$_connection_profiles/options', id.value),
    createItem: () => $store.dispatch('$_connection_profiles/createConnectionProfile', form.value),
    deleteItem: () => $store.dispatch('$_connection_profiles/deleteConnectionProfile', id.value),
    getItem: () => $store.dispatch('$_connection_profiles/getConnectionProfile', id.value).then(item => {
      const _item = JSON.parse(JSON.stringify(item))
      if (isClone.value) {
        _item.id = `${item.id}-${i18n.t('copy')}`
        _item.not_deletable = false
      }
      return _item
    }),
    updateItem: () => $store.dispatch('$_connection_profiles/updateConnectionProfile', form.value)
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
