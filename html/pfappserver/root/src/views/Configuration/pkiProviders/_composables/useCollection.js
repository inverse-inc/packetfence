import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { pkiProvidersTypes } from '../config'

export const useItemProps = {
  id: {
    type: String
  },
  providerType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    providerType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: providerType.value }
}

export const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('PKI Provider <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone PKI Provider <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New PKI Provider')
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    providerType
  } = toRefs(props)
  return computed(() => pkiProvidersTypes[providerType.value || form.value.type])
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('pkiProviders', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'p-0',
      locked: true
    },
    {
      key: 'id',
      label: 'Name', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'type',
      label: 'Type', // i18n defer
      searchable: true,
      sortable: true,
      visible: true,
      formatter: value => pkiProvidersTypes[value]
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
      text: i18n.t('Name'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'type',
      text: i18n.t('Type'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id',
  defaultCondition: () => ({ op: 'and', values: [
    { op: 'or', values: [
      { field: 'id', op: 'contains', value: null },
      { field: 'type', op: 'contains', value: null }
    ] }
  ] })
})
