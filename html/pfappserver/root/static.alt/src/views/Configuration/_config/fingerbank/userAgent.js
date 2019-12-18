import i18n from '@/utils/locale'
import api from '@/views/Configuration/_api'
import pfFormInput from '@/components/pfFormInput'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  required
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'value',
    label: i18n.t('User Agent'),
    sortable: true,
    visible: true
  },
  {
    key: 'created_at',
    label: i18n.t('Created'),
    sortable: true,
    visible: true
  },
  {
    key: 'updated_at',
    label: i18n.t('Updated'),
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

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'fingerbankUserAgent', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or user agent'),
    searchableOptions: {
      searchApiEndpoint: `fingerbank/local/user_agents`,
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
      defaultRoute: { name: 'fingerbankUserAgents' }
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

export const view = (form = {}, meta = {}) => {
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
          label: i18n.t('User Agent'),
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

export const validators = (form = {}, meta = {}) => {
  return {
    value: {
      [i18n.t('User agent required.')]: required
    }
  }
}

export const search = (chosen, query) => {
  if (!query) return []
  if (chosen.inputValue !== null && chosen.options.length === 0) { // first query - presearch current value
    return api.fingerbankSearchUserAgents({
      query: { op: 'and', values: [{ op: 'or', values: [{ field: 'id', op: 'equals', value: query }] }] },
      fields: ['id', 'value'],
      sort: ['value'],
      cursor: 0,
      limit: 100
    }).then(response => {
      return response.items.map(item => {
        return { value: item.id.toString(), text: item.value }
      })
    })
  } else { // subsequent queries
    const currentOption = chosen.options.find(option => option.value === chosen.inputValue) // cache current value
    return api.fingerbankSearchUserAgents({
      query: { op: 'and', values: [{ op: 'or', values: [{ field: 'value', op: 'contains', value: query }] }] },
      fields: ['id', 'value'],
      sort: ['value'],
      cursor: 0,
      limit: 100
    }).then(response => {
      return [
        ...((currentOption) ? [currentOption] : []), // current option first
        ...response.items.map(item => {
          return { value: item.id.toString(), text: item.value }
        }).filter(item => {
          return JSON.stringify(item) !== JSON.stringify(currentOption) // remove duplicate current option
        })
      ]
    })
  }
}
