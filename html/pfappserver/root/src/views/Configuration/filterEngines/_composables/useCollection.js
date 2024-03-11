import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  collection: {
    type: String
  },
  id: {
    type: String
  },
  type: {
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
        return i18n.t('Filter <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Filter <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Filter')
    }
  })
}

export const useItemTitleBadge = (props, context) => {
  const {
    collection
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return computed(() => $store.getters['$_filter_engines/collectionToName'](collection.value))
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('filterEngines', {
  api,
  sortBy: null, // use natural order (sortable)
  columns: [ // output uses natural order (w/ sortable drag-drop), ensure NO columns are 'sortable: true'
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'status',
      label: 'Status', // i18n defer
      visible: true
    },
    {
      key: 'type',
      label: 'Type', // i18n defer
      searchable: true,
      visible: true
    },
    {
      key: 'id',
      label: 'Name', // i18n defer
      required: true,
      searchable: true,
      visible: true
    },
    {
      key: 'description',
      label: 'Description', // i18n defer
      searchable: true,
      visible: true
    },
    {
      key: 'scopes',
      label: 'Scopes', // i18n defer
      visible: true,
      /*
      formatter: (value) => {
        if (value && value.constructor === Array && value.length > 0) {
          return value
        }
        return null // otherwise '[]' is displayed in cell
      }
      */
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
    },
    {
      key: 'not_sortable',
      required: true,
      visible: false
    },
  ],
  fields: [
    {
      value: 'id',
      text: i18n.t('Name'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'description',
      text: i18n.t('Description'),
      types: [conditionType.SUBSTRING]
    }
  ]
})
