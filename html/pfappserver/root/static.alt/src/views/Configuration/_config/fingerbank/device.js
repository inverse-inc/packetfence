import i18n from '@/utils/locale'
import api from '@/views/Configuration/_api'
import pfFormChosen from '@/components/pfFormChosen'
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
    key: 'name',
    label: i18n.t('Device'),
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
    key: 'approved',
    label: i18n.t('Approved'),
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
    scope = 'all',
    parentId = null
  } = context
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'fingerbankDevice', params: { scope: scope, id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or device'),
    searchableOptions: {
      searchApiEndpoint: `fingerbank/${scope}/devices`, // `./search` automatically appended
      searchApiEndpointOnly: true, // always use `/search` endpoint
      defaultSortKeys: ['name'],
      defaultSearchCondition: {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'parent_id', op: 'equals', value: ((parentId) || null) }
            ]
          }
        ]
      },
      defaultRoute: { name: 'fingerbankDevices' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          ...((!quickCondition.trim())
            ? [{ op: 'or', values: [{ field: 'parent_id', op: 'equals', value: ((parentId) || null) }] }]
            : []
          ),
          ...((quickCondition.trim())
            ? [{
              op: 'or',
              values: [
                { field: 'id', op: 'contains', value: quickCondition.trim() },
                { field: 'name', op: 'contains', value: quickCondition.trim() }
              ]
            }]
            : []
          )
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
          label: i18n.t('Name'),
          cols: [
            {
              namespace: 'name',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Parent device'),
          cols: [
            {
              namespace: 'parent_id',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Type to search'),
                trackBy: 'value',
                label: 'text',
                searchable: true,
                internalSearch: false,
                preserveSearch: true,
                clearOnSelect: false,
                allowEmpty: false,
                optionsLimit: 100,
                optionsSearchFunction: search
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  return {
    name: {
      [i18n.t('Name required.')]: required
    }
  }
}

export const search = (chosen, query) => {
  if (!query) return []
  if (chosen.value !== null && chosen.options.length === 0) { // first query - presearch current value
    return api.fingerbankSearchDevices({
      query: { op: 'and', values: [{ op: 'or', values: [{ field: 'id', op: 'equals', value: query }] }] },
      fields: ['id', 'name'],
      sort: ['name'],
      cursor: 0,
      limit: 100
    }).then(response => {
      return response.items.map(item => {
        return { value: item.id.toString(), text: item.name }
      })
    })
  } else { // subsequent queries
    const currentOption = chosen.options.find(option => option.value === chosen.value) // cache current value
    return api.fingerbankSearchDevices({
      query: { op: 'and', values: [{ op: 'or', values: [{ field: 'name', op: 'contains', value: query }] }] },
      fields: ['id', 'name'],
      sort: ['name'],
      cursor: 0,
      limit: 100
    }).then(response => {
      return [
        ...((currentOption) ? [currentOption] : []), // current option first
        ...response.items.map(item => {
          return { value: item.id.toString(), text: item.name }
        }).filter(item => {
          return JSON.stringify(item) !== JSON.stringify(currentOption) // remove duplicate current option
        })
      ]
    })
  }
}
