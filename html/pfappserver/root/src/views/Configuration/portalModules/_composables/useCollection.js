import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  moduleType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    moduleType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: moduleType.value }
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
        return i18n.t('Portal Module <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Portal Module <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Portal Module')
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    moduleType
  } = toRefs(props)
  return computed(() => (moduleType.value || form.value.type))
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('portalModules', {
  api,
  columns: [
    {
      key: 'id',
      label: 'Name', // i18n defer
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
      key: 'modules',
      label: 'Modules', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    }
  ],
  fields: [
    {
      value: 'id',
      text: 'Name',
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'description',
      text: 'Description',
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'type',
      text: 'Type',
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id',
  limit: 1000
})