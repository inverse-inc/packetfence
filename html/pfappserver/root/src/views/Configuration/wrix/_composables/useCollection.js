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
        return i18n.t('WRIX Location <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone WRIX Location <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New WRIX Location')
    }
  })
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('wrixLocations', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'id',
      label: 'WRIX Identifier', // i18n defer
      searchable: true,
      required: true,
      sortable: true,
      visible: true
    },
    {
      key: 'Provider_Identifier',
      label: 'Provider Identifier', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'Location_Identifier',
      label: 'Location Identifier', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'Service_Provider_Brand',
      label: 'Service Provider Brand', // i18n defer
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
      value: 'id',
      text: i18n.t('WRIX Identifier'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'Provider_Identifier',
      text: i18n.t('Provider Identifier'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'Location_Identifier',
      text: i18n.t('Location Identifier'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'Service_Provider_Brand',
      text: i18n.t('Service Provider Brand'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id'
})
