import i18n from '@/utils/locale'
import api from '../../fingerbank/_api'
import pfFormInput from '@/components/pfFormInput'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  isOUI
} from '@/globals/pfValidators'
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
    key: 'mac',
    label: 'OUI', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'name',
    label: 'MAC Vendor', // i18n defer
    sortable: true,
    visible: true
  },
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
      return { name: 'fingerbankMacVendor', params: { scope: scope, id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or MAC vendor'),
    searchableOptions: {
      searchApiEndpoint: `fingerbank/${scope}/mac_vendors`,
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
      defaultRoute: { name: 'fingerbankMacVendors' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'mac', op: 'contains', value: quickCondition },
              { field: 'name', op: 'contains', value: quickCondition }
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
          label: i18n.t('MAC Vendor'),
          cols: [
            {
              namespace: 'name',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('OUI'),
          text: i18n.t('The OUI is the first six digits or letters of a MAC address. They must be entered without any space or separator (ex: 001122).'),
          cols: [
            {
              namespace: 'mac',
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
    name: {
      [i18n.t('Vendor required.')]: required
    },
    mac: {
      [i18n.t('OUI required.')]: required,
      [i18n.t('Invalid OUI.')]: isOUI
    }
  }
}

export const search = (chosen, query, searchById) => {
  if (!query) return []
  return api.fingerbankSearchMacVendors({
    query: ((searchById)
      ? { op: 'and', values: [{ op: 'or', values: [{ field: 'id', op: 'equals', value: query }] }] }
      : { op: 'and', values: [{ op: 'or', values: [{ field: 'id', op: 'contains', value: query }, { field: 'name', op: 'contains', value: query }, { field: 'mac', op: 'contains', value: query }] }] }
    ),
    fields: ['id', 'mac', 'name'],
    sort: ['name'],
    cursor: 0,
    limit: 100
  }).then(response => {
    return response.items.map(item => {
      return { value: item.id, text: `${item.mac.toUpperCase()} - ${item.name}` }
    })
  })
}
