import i18n from '@/utils/locale'
import api from '../../fingerbank/_api'
import pfFormInput from '@/components/pfFormInput'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  required
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'id',
    label: 'Identifier', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'value',
    label: 'DHCPv6 Enterprise', // i18n defer
    sortable: true,
    visible: true
  },
  /* TODO - Issue #4217
  {
    key: 'organization',
    label: 'Organization', // i18n defer
    sortable: true,
    visible: true
  },
  */
  {
    key: 'created_at',
    label: 'Created', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'updated_at',
    label: 'Updated', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]

export const fields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = (context = {}) => {
  const {
    scope
  } = context
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'fingerbankDhcpv6Enterprise', params: { scope: scope, id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or DHCPv6 enterprise'),
    searchableOptions: {
      searchApiEndpoint: `fingerbank/${scope}/dhcp6_enterprises`,
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'fingerbankDhcpv6Enterprises' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'value', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const view = (_, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          if: (!isNew && !isClone),
          label: i18n.t('Identifier'),
          cols: [
            {
              namespace: 'id',
              component: pfFormInput,
              attrs: {
                disabled: true
              }
            }
          ]
        },
        {
          label: i18n.t('DHCPv6 Enterprise'),
          cols: [
            {
              namespace: 'value',
              component: pfFormInput
            }
          ]
        }
      ]
    }
  ]
}

export const validators = () => {
  return {
    value: {
      [i18n.t('Enterprise required.')]: required
    }
  }
}

export const search = (chosen, query, searchById) => {
  if (!query) return []
  return api.fingerbankSearchDhcpv6Enterprises({
    query: ((searchById)
      ? { op: 'and', values: [{ op: 'or', values: [{ field: 'id', op: 'equals', value: query }] }] }
      : { op: 'and', values: [{ op: 'or', values: [{ field: 'value', op: 'contains', value: query }] }] }
    ),
    fields: ['id', 'value'],
    sort: ['value'],
    cursor: 0,
    limit: 100
  }).then(response => {
    return response.items.map(item => {
      return { value: item.id.toString(), text: item.value }
    })
  })
}
