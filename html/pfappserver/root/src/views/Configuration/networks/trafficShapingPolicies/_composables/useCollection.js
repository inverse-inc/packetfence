import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    role
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), id: role.value }
}

export const useItemTitle = (props) => {
  const {
    id,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value:
        return i18n.t('Traffic Shaping Policy <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Traffic Shaping Policy')
    }
  })
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('trafficShapingPolicies', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'id',
      label: 'Role', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'upload',
      label: 'Upload', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'download',
      label: 'Download', // i18n defer
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
      text: i18n.t('Role'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'upload',
      text: i18n.t('Upload'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'download',
      text: i18n.t('Download'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id'
})
