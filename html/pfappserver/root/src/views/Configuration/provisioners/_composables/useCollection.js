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
  return computed(() => provisioningTypes[provisioningType.value || form.value.type])
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id,
    isClone,
    isNew,
    provisioningType
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_provisionings/isLoading']),
    getOptions: () => {
      if (isNew.value)
        return $store.dispatch('$_provisionings/optionsByProvisioningType', provisioningType.value)
      else
        return $store.dispatch('$_provisionings/optionsById', id.value)
    },
    createItem: () => $store.dispatch('$_provisionings/createProvisioning', form.value),
    deleteItem: () => $store.dispatch('$_provisionings/deleteProvisioning', id.value),
    getItem: () => $store.dispatch('$_provisionings/getProvisioning', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_provisionings/updateProvisioning', form.value),
  }
}

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('provisioners', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'p-0',
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
      key: 'description',
      label: 'Description', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'type',
      label: 'Type', // i18n defer
      sortable: true,
      visible: true,
      formatter: value => provisioningTypes[value]
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
  sortBy: 'id',
  defaultCondition: () => ({ op: 'and', values: [
    { op: 'or', values: [
      { field: 'id', op: 'contains', value: null },
      { field: 'description', op: 'contains', value: null }
    ] }
  ] })
})
