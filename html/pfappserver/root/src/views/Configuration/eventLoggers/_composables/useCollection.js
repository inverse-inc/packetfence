import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  eventLoggerType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    eventLoggerType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: eventLoggerType.value }
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
        return i18n.t('Event Logger <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Event Logger <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Event Logger')
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    eventLoggerType
  } = toRefs(props)
  return computed(() => (eventLoggerType.value || form.value.type))
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('eventLoggers', {
  api,
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
      key: 'description',
      label: 'Description', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'host',
      label: 'Host', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'port',
      label: 'Port', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'facility',
      label: 'Facility', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'namespaces',
      label: 'Namespaces', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'priority',
      label: 'Priority', // i18n defer
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
      key: 'not_deletable',
      required: true,
      visible: false
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
      value: 'host',
      text: i18n.t('Host'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'port',
      text: i18n.t('Port'),
      types: [conditionType.INTEGER]
    },
    {
      value: 'facility',
      text: i18n.t('Facility'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'namespaces',
      text: i18n.t('Namespaces'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'priority',
      text: i18n.t('Priority'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id'
})
