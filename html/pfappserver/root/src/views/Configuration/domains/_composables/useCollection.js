import { computed, toRefs } from '@vue/composition-api'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
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
        return i18n.t('Domain <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Domain <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Domain')
    }
  })
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_domains/isLoading']),
    getOptions: () => $store.dispatch('$_domains/options'),
    createItem: () => $store.dispatch('$_domains/createDomain', form.value),
    deleteItem: () => $store.dispatch('$_domains/deleteDomain', id.value),
    getItem: () => $store.dispatch('$_domains/getDomain', id.value),
    updateItem: () => $store.dispatch('$_domains/updateDomain', form.value),
  }
}

import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('domains', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'p-0',
      locked: true
    },
    {
      key: 'id',
      label: 'Identifier', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'workgroup',
      label: 'Workgroup', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'ntlm_cache',
      label: 'NTLM Cache', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'joined',
      label: 'Domain Join', // i18n defer
      locked: true
    },
    {
      key: 'buttons',
      class: 'text-right p-0',
      locked: true
    }
  ],
  fields: [
    {
      value: 'id',
      text: i18n.t('Identifier'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'workgroup',
      text: i18n.t('Workgroup'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id',
  defaultCondition: () => ([{
    values: [
      { field: 'id', op: 'contains', value: null },
      { field: 'workgroup', op: 'contains', value: null }
    ]
  }])
})
