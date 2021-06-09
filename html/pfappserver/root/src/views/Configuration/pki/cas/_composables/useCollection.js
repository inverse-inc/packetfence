import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  decomposeCa,
  recomposeCa
} from '../config'

export const useItemProps = {
  id: {
    type: String
  }
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
        return i18n.t('Certificate Authority <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Certificate Authority <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Certificate Authority')
    }
  })
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_pkis/isLoading']),
    createItem: () => $store.dispatch('$_pkis/createCa', recomposeCa(form.value)),
    getItem: () => $store.dispatch('$_pkis/getCa', id.value)
      .then(item => decomposeCa(item))
  }
}

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('pkiCas', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'p-0',
      locked: true
    },
    {
      key: 'ID',
      label: 'Identifier', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'cn',
      label: 'Common Name', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'mail',
      label: 'Email', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'organisation',
      label: 'Organisation', // i18n defer
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
      value: 'ID',
      text: i18n.t('Identifier'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'cn',
      text: i18n.t('Common Name'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'mail',
      text: i18n.t('Email'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'organisation',
      text: i18n.t('Organisation'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id',
  defaultCondition: () => ({ op: 'and', values: [
    { op: 'or', values: [
      { field: 'ID', op: 'contains', value: null },
      { field: 'cn', op: 'contains', value: null },
      { field: 'mail', op: 'contains', value: null },
      { field: 'organisation', op: 'contains', value: null }
    ] }
  ] })
})
