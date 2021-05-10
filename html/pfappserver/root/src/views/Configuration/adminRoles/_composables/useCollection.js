import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Admin Role <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Admin Role <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Admin Role')
    }
  })
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_admin_roles/isLoading']),
    getOptions: () => $store.dispatch('$_admin_roles/options'),
    createItem: () => $store.dispatch('$_admin_roles/createAdminRole', form.value),
    deleteItem: () => $store.dispatch('$_admin_roles/deleteAdminRole', id.value),
    getItem: () => $store.dispatch('$_admin_roles/getAdminRole', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_admin_roles/updateAdminRole', form.value),
  }
}

import { useSearch as useConfigurationSearch } from '@/views/Configuration/_composables/useSearch'
import api from '../_api'
import {
  columns,
  fields
} from '../config'
export const useSearch = (props, context, options) => useConfigurationSearch(props, context, {
  id: 'adminRoles',
  api,
  columns,
  fields,
  sortBy: 'id',
  defaultCondition: () => ([{ values: [
    { field: 'id', op: 'contains', value: null },
    { field: 'description', op: 'contains', value: null }
  ] }]),
  ...options,
})
