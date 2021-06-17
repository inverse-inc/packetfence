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
        return i18n.t('Billing Tier <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Billing Tier <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Billing Tier')
    }
  })
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('billingTiers', {
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
      sortable: true,
      visible: true,
      searchable: true
    },
    {
      key: 'name',
      label: 'Name', // i18n defer
      sortable: true,
      visible: true,
      searchable: true
    },
    {
      key: 'description',
      label: 'Description', // i18n defer
      sortable: true,
      visible: true,
      searchable: true
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
      value: 'description',
      text: i18n.t('Description'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'name',
      text: i18n.t('Name'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id'
})
