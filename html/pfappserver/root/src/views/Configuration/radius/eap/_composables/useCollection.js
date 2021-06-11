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
        return i18n.t('EAP Profile <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone EAP Profile <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New EAP Profile')
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
    isLoading: computed(() => $store.getters['$_radius_eap/isLoading']),
    getOptions: () => $store.dispatch('$_radius_eap/options'),
    createItem: () => $store.dispatch('$_radius_eap/createRadiusEap', form.value),
    deleteItem: () => $store.dispatch('$_radius_eap/deleteRadiusEap', id.value),
    getItem: () => $store.dispatch('$_radius_eap/getRadiusEap', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    ...((id.value === 'default' && !isClone.value)
      ? {} // don't update id: default
      : {
        updateItem: () => $store.dispatch('$_radius_eap/updateRadiusEap', form.value)
      }
    )
  }
}

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('radiusEap', {
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
      key: 'default_eap_type',
      label: 'Default EAP', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'tls_tlsprofile',
      label: 'TLS Profile', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'ttls_tlsprofile',
      label: 'TTLS Profile', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'peap_tlsprofile',
      label: 'PEAP Profile', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'fast_config',
      label: 'Fast Profile', // i18n defer
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
      text: i18n.t('Name'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id',
  defaultCondition: () => ({ op: 'and', values: [
    { op: 'or', values: [
      { field: 'id', op: 'contains', value: null }
    ] }
  ] })
})
