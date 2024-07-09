import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { types } from '../config'

export const useItemProps = {
  id: {
    type: String
  },
  eventHandlerType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    eventHandlerType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: eventHandlerType.value }
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
        return i18n.t('Event Handler <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Event Handler <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Event Handler')
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    eventHandlerType
  } = toRefs(props)
  return computed(() => {
    const type = eventHandlerType.value || form.value.type
    return types[type]
  })
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('eventHandlers', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'status',
      label: 'Status', // i18n defer
      sortable: true,
      visible: true
    },
    {
      key: 'id',
      label: 'Detector', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'type',
      label: 'Type', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true,
      formatter: value => types[value]
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
      text: i18n.t('Detector'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'type',
      text: i18n.t('Type'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id'
})
