import i18n from '@/utils/locale'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export const columns = [
  {
    key: 'id',
    label: 'Identifier', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'description',
    label: 'Description', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'group',
    label: 'Group', // i18n defer
    sortable: true,
    visible: true,
    formatter: (value, key, item) => {
      if (!value) item.group = i18n.t('default')
    }
  },
  {
    key: 'type',
    label: 'Type', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'mode',
    label: 'Mode', // i18n defer
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
  },
  {
    value: 'description',
    text: i18n.t('Description'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'mode',
    text: i18n.t('Mode'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'type',
    text: i18n.t('Type'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'switch', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/switches',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'description', op: 'contains', value: null },
            { field: 'type', op: 'contains', value: null },
            { field: 'mode', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'switches' },
      extraFields: {
        raw: 1
      }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'description', op: 'contains', value: quickCondition },
              { field: 'type', op: 'contains', value: quickCondition },
              { field: 'mode', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const importFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [fieldType.SUBSTRING],
    required: true
  },
  {
    value: 'description',
    text: i18n.t('Description'),
    types: [fieldType.SUBSTRING],
    required: true
  },
  {
    value: 'type',
    text: i18n.t('Type'),
    types: [fieldType.SUBSTRING],
    required: false,
    /*
    validators: {
      [i18n.t('Switch type does not exist.')]: switchTypeExists
    }
    */
  },
  {
    value: 'mode',
    text: i18n.t('Mode'),
    types: [fieldType.SUBSTRING],
    required: false,
    /*
    validators: {
      [i18n.t('Switch mode does not exist.')]: switchModeExists
    }
    */
  },
  {
    value: 'group',
    text: i18n.t('Switch Group'),
    types: [fieldType.SUBSTRING],
    required: false,
    /*
    validators: {
      [i18n.t('Switch group does not exist.')]: switchGroupExists
    }
    */
  }
]
