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

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('networkCommunication', {
  api,
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

export const useSearchData = makeSearch('networkCommunicationData', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'text-align: center; width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'timestamp',
      label: i18n.t('Timestamp'),
      searchable: true,
      required: true,
      sortable: true,
      visible: true
    },
    {
      key: 'device_class',
      label: i18n.t('Category'),
      searchable: true,
      required: true,
      sortable: true,
      visible: true
    },
    {
      key: 'mac',
      label: i18n.t('Device'),
      searchable: true,
      required: true,
      sortable: true,
      visible: true
    },
    {
      key: 'proto',
      label: i18n.t('Proto'),
      searchable: true,
      required: true,
      sortable: true,
      visible: true
    },
    {
      key: 'port',
      label: i18n.t('Port'),
      searchable: true,
      required: true,
      sortable: true,
      visible: true
    },
    {
      key: 'host',
      label: i18n.t('Host'),
      searchable: true,
      required: true,
      sortable: true,
      visible: true
    },
    {
      key: 'buttons',
      class: 'text-right p-0',
      locked: true
    },

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
