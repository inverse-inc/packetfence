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

export { useStore } from '../_store'

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
