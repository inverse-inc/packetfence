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

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('tenants', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'p-0',
      locked: true
    },
    {
      key: 'id',
      class: 'text-nowrap',
      label: 'Identifier', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'name',
      label: 'Name', // i18n defer
      sortable: true,
      visible: true,
      searchable: true
    },
    {
      key: 'domain_name',
      label: 'Domain Name', // i18n defer
      sortable: true,
      visible: true,
      searchable: true
    },
    {
      key: 'portal_domain_name',
      label: 'Portal Domain Name', // i18n defer
      sortable: true,
      visible: true,
      searchable: true
    },
    {
      key: 'buttons',
      class: 'text-right p-0',
      locked: true
    },
    {
      key: 'not_deletable',
      required: true,
      visible: false
    }
  ],
  fields: [
    {
      value: 'id',
      text: i18n.t('Identifier'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'name',
      text: i18n.t('Name'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'domain_name',
      text: i18n.t('Domain name'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'portal_domain_name',
      text: i18n.t('Portal domain name'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id'
})
