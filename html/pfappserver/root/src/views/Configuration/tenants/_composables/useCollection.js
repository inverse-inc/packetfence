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
        return i18n.t('Tenant <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Tenant <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Tenant')
    }
  })
}

export const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'tenants' }),
    goToItem: (item = form.value || {}) => $router
      .push({ name: 'tenant', params: { id: item.id } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneTenant', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
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
    getItem: () => $store.dispatch('$_tenants/getTenant', id.value).then(item => {
      if (isClone.value) {
        item.name = `${item.name}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_tenants/updateTenant', form.value),
  }
}

import {
  useSearch as useConfigurationSearch
} from '@/views/Configuration/_composables/useSearch'
import api from '../_api'
import {
  columns,
  fields
} from '../config'
export const useSearch = (props, context, options) => {
  return useConfigurationSearch(api, { 
    name: 'tenants', // localStorage prefix
    columns,
    fields,
    sortBy: 'id',
    ...options,
  })
}

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
  useSearch
}
