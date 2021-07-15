import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  scope: {
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
        return i18n.t('Fingerbank Device <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Fingerbank Device <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Fingerbank Device')
    }
  })
}

export const useItemTitleBadge = props => props.scope

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import api from '../_api'
const { list, ...apiWithoutList } = api
export const useSearch = makeSearch('fingerbankDevices', {
  api: apiWithoutList,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
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
      key: 'name',
      label: 'Device', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'created_at',
      label: 'Created', // i18n defer
      sortable: true,
      visible: true
    },
    {
      key: 'updated_at',
      label: 'Updated', // i18n defer
      sortable: true,
      visible: true
    },
    {
      key: 'approved',
      label: 'Approved', // i18n defer
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
      text: i18n.t('Identifier'),
      types: [conditionType.INTEGER]
    },
    {
      value: 'name',
      text: i18n.t('Device'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'parent_id',
      text: i18n.t('Parent'),
      types: [conditionType.INTEGER]
    }
  ],
  sortBy: 'name',
  defaultCondition: () => ({ op: 'and', values: [
    { op: 'or', values: [
      { field: 'parent_id', op: 'equals', value: null }
    ] }
  ] })
})
