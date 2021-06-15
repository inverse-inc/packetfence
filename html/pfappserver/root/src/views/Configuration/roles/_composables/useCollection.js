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
        return i18n.t('Role <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Role <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Role')
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
  id: 'roles',
  api,
  columns,
  fields,
  sortBy: 'id',
  defaultCondition: () => ([{ values: [{ field: 'parent_id', op: 'equals', value: null }] }]),
  ...options,
})
