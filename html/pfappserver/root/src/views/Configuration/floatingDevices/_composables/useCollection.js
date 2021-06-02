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
        return i18n.t('Floating Device <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Floating Device <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Floating Device')
    }
  })
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_floatingdevices/isLoading']),
    getOptions: () => $store.dispatch('$_floatingdevices/options', id.value),
    createItem: () => $store.dispatch('$_floatingdevices/createFloatingDevice', form.value),
    deleteItem: () => $store.dispatch('$_floatingdevices/deleteFloatingDevice', id.value),
    getItem: () => $store.dispatch('$_floatingdevices/getFloatingDevice', id.value).then(item => {
      if (isClone.value)
        item.not_deletable = false
      return item
    }),
    updateItem: () => $store.dispatch('$_floatingdevices/updateFloatingDevice', form.value)
  }
}

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('firewalls', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'p-0',
      locked: true
    },
    {
      key: 'id',
      label: 'MAC', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'ip',
      label: 'IP Address', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'pvid',
      label: 'Native VLAN', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'taggedVlan',
      label: `Tagged VLAN's`, // i18n defer
      sortable: false,
      visible: true
    },
    {
      key: 'trunkPort',
      label: 'Trunk Port', // i18n defer
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
      text: i18n.t('MAC'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'ip',
      text: i18n.t('IP Address'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'pvid',
      text: i18n.t('Native VLAN'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id',
  defaultCondition: () => ({ op: 'and', values: [
    { op: 'or', values: [
      { field: 'id', op: 'contains', value: null },
      { field: 'ip', op: 'contains', value: null }
    ] }
  ] })
})
