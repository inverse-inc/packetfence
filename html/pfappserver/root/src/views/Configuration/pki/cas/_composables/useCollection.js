import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  }
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
        return i18n.t('Certificate Authority <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Certificate Authority <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Certificate Authority')
    }
  })
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('pkiCas', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'p-0',
      locked: true
    },
    {
      key: 'ID',
      label: 'Identifier', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'cn',
      label: 'Common Name', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'mail',
      label: 'Email', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'organisation',
      label: 'Organisation', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'buttons',
      class: 'text-right p-0',
      locked: true
    }
  ],
  fields: [
    {
      value: 'ID',
      text: i18n.t('Identifier'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'cn',
      text: i18n.t('Common Name'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'mail',
      text: i18n.t('Email'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'organisation',
      text: i18n.t('Organisation'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id',
  defaultCondition: () => ({ op: 'and', values: [
    { op: 'or', values: [
      { field: 'ID', op: 'not_equals', value: null }
    ] }
  ] })
})
