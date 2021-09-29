import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { provisioningTypes } from '../config'

export const useItemProps = {
  id: {
    type: String
  },
  provisioningType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    provisioningType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: provisioningType.value }
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
        return i18n.t('Provisioner <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Provisioner <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Provisioner')
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    provisioningType
  } = toRefs(props)
  return computed(() => {
    const type = provisioningType.value || form.value.type
    return provisioningTypes[type]
  })
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('provisioners', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'id',
      label: 'Name', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'type',
      label: 'Type', // i18n defer
      required: true,
      sortable: true,
      visible: true,
      formatter: value => provisioningTypes[value]
    },
    {
      key: 'description',
      label: 'Description', // i18n defer
      searchable: true,
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
      text: i18n.t('Name'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'description',
      text: i18n.t('Description'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id'
})
