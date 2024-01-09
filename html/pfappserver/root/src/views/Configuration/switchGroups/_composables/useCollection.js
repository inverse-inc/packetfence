
import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  switchGroup: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    switchGroup
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), group: switchGroup.value }
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
        return i18n.t('Switch Group <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Switch Group <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Switch Group')
    }
  })
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('switchGroups', {
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
      key: 'type',
      label: 'Type', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'mode',
      label: 'Mode', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'UsePushACLs',
      label: 'Push ACLs', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'UseDownloadableACLs',
      label: 'Downloadable ACLs', // i18n defer
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
      value: 'mode',
      text: i18n.t('Mode'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'type',
      text: i18n.t('Type'),
      types: [conditionType.SUBSTRING]
    },
  ],
  sortBy: 'id'
})
