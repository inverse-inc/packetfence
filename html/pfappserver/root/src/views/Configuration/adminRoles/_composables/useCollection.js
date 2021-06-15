import { computed, toRefs } from '@vue/composition-api'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
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
        return i18n.t('Admin Role <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Admin Role <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Admin Role')
    }
  })
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('adminRoles', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'p-0',
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
      sortable: true,
      searchable: true,
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
      text: i18n.t('Role Name'),
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
      { field: 'id', op: 'not_equals', value: null }
    ] }
  ]
  }),
/*
  requestInterceptor: request => {
    // append query in request to omit NONE, ALL, ALL_PF_ONLY from request
    request.query.values = [
      ...request.query.values,
      { op: 'or', values: [ { field: 'id', op: 'not_equals', value: 'NONE' } ] },
      { op: 'or', values: [ { field: 'id', op: 'not_equals', value: 'ALL' } ] },
      { op: 'or', values: [ { field: 'id', op: 'not_equals', value: 'ALL_PF_ONLY' } ] }
    ]
    return request
  }
*/
})
