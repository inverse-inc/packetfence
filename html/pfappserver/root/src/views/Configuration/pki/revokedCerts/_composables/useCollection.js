import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  }
}

export const useItemTitle = (props) => {
  const {
    id
  } = toRefs(props)
  return computed(() => i18n.t('Revoked Certificate <code>{id}</code>', { id: id.value }))
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
import { revokeReasons } from '../../config'
export const useSearch = makeSearch('pkiRevokedCerts', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
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
      key: 'ca_id',
      required: true
    },
    {
      key: 'ca_name',
      label: 'Certificate Authority', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'profile_id',
      required: true
    },
    {
      key: 'profile_name',
      label: 'Template', // i18n defer
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
      key: 'valid_until',
      label: 'Valid Until', // i18n defer
      sortable: true,
      visible: true
    },
    {
      key: 'crl_reason',
      label: 'Reason', // i18n defer
      sortable: true,
      visible: true,
      formatter: value => {
        const reason = revokeReasons.find(reason => reason.value === value.toString())
        return reason.text || ''
      }
    },
    {
      key: 'buttons',
      thStyle: 'width: 40px;', class: 'text-right p-0',
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
      value: 'ca_id',
      text: i18n.t('Certificate Authority Identifier'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'ca_name',
      text: i18n.t('Certificate Authority Name'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'profile_id',
      text: i18n.t('Template Identifier'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'profile_name',
      text: i18n.t('Template Name'),
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
    }
  ],
  sortBy: 'id',
  defaultCondition: () => ({ op: 'and', values: [
    { op: 'or', values: [
      { field: 'ID', op: 'not_equals', value: null }
    ] }
  ] })
})
