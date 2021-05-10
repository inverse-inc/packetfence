import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemTitle = (props, context) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  const { root: { $store } = {} } = context
  const { [id.value]: { name } = {} } = $store.getters['$_tenants/all'] // use store, not form
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Tenant <code>{name}</code>', { name })
      case isClone.value:
        return i18n.t('Clone Tenant <code>{name}</code>', { name })
      default:
        return i18n.t('New Tenant')
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
    isLoading: computed(() => $store.getters['$_tenants/isLoading']),
    getOptions: () => $store.dispatch('$_tenants/options'),
    createItem: () => $store.dispatch('$_tenants/createTenant', form.value),
    deleteItem: () => $store.dispatch('$_tenants/deleteTenant', id.value),
    getItem: () => $store.dispatch('$_tenants/getTenant', id.value).then(_item => {
      let item = { ..._item } // dereference
      if (isClone.value) {
        item.name = `${item.name}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_tenants/updateTenant', form.value),
  }
}

import { useSearch as useConfigurationSearch } from '@/views/Configuration/_composables/useSearch'
import api from '../_api'
import {
  columns,
  fields
} from '../config'
export const useSearch = (props, context, options) => useConfigurationSearch(props, context, {
  id: 'tenants',
  api,
  columns,
  fields,
  sortBy: 'id',
  defaultCondition: () => ([{ values: [{ field: 'name', op: 'contains', value: null }] }]),
  ...options,
})
