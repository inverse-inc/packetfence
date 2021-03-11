import i18n from '@/utils/locale'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export const columns = [
  {
    key: 'ID',
    label: 'Identifier', // i18n defer
    required: true,
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
    sortable: true,
    visible: true
  },
  {
    key: 'cn',
    label: 'Common Name', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'mail',
    label: 'Email', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'revoked',
    label: 'Revoked', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'crl_reason',
    label: 'Reason', // i18n defer
    sortable: true,
    sortByFormatted: true,
    visible: true
  }
]

export const fields = [
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
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'pkiRevokedCert', params: { id: item.ID } }
    },
    searchPlaceholder: i18n.t('Search by identifier, certificate authority, template, common name or email'),
    searchableOptions: {
      searchApiEndpoint: 'pki/revokedcerts',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'ca_name', op: 'contains', value: null },
            { field: 'profile_name', op: 'contains', value: null },
            { field: 'cn', op: 'contains', value: null },
            { field: 'mail', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'pkiRevokedCerts' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'ca_name', op: 'contains', value: quickCondition },
              { field: 'profile_name', op: 'contains', value: quickCondition },
              { field: 'cn', op: 'contains', value: quickCondition },
              { field: 'mail', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}
