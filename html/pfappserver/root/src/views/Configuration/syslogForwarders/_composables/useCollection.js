import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  syslogForwarderType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    syslogForwarderType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: syslogForwarderType.value }
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
        return i18n.t('Syslog Entry <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Syslog Entry <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Syslog Entry')
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    syslogForwarderType
  } = toRefs(props)
  return computed(() => (syslogForwarderType.value || form.value.type))
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('syslogForwarders', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'id',
      label: 'Syslog Name', // i18n defer
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
      text: i18n.t('Syslog Name'),
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
