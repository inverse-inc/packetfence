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
        return i18n.t('Role: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Role: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Role')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'roles' }),
    goToItem: () => $router.push({ name: 'role', params: { id: form.value.id || id.value } }),
    goToClone: () => $router.push({ name: 'cloneRole', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_roles/isLoading']),
    getOptions: () => $store.dispatch('$_roles/options'),
    createItem: () => $store.dispatch('$_roles/createRole', form.value),
    deleteItem: () => $store.dispatch('$_roles/deleteRole', id.value),
    getItem: () => $store.dispatch('$_roles/getRole', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_roles/updateRole', form.value),
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
