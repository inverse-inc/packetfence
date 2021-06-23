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

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('roles', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'text-align: center; width: 40px;', tdClass: 'text-center',
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
      key: 'notes',
      label: 'Description', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'max_nodes_per_pid',
      label: 'Max nodes per user', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'buttons',
      class: 'text-right p-0',
      locked: true
    },
    {
      key: 'children',
      required: true
    },
    {
      key: 'parent_id',
      required: true
    }
  ],
  fields: [
    {
      value: 'id',
      text: i18n.t('Name'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'notes',
      text: i18n.t('Description'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'parent_id',
      text: i18n.t('Parent Role'),
      types: [conditionType.ROLE]
    }
  ],
  sortBy: 'id'
})
